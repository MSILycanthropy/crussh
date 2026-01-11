# Crussh

[![Gem Version](https://badge.fury.io/rb/crussh.svg)](https://badge.fury.io/rb/crussh)
[![Build Status](https://github.com/MSILycanthropy/crussh/actions/workflows/main.yml/badge.svg)](https://github.com/MSILycanthropy/crussh/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.3-ruby.svg)](https://www.ruby-lang.org)

A low-level SSH server library for Ruby.

<details>
  <summary>
    <strong>Algorithm Support</strong>
  </summary>

- Ciphers:
  - `chacha20-poly1305@openssh.com`
- Key exchanges:
  - `curve25519-sha256`
  - `curve25519-sha256@libssh.org`
- Host keys:
  - `ssh-ed25519`
  - `rsa-sha2-256`
  - `rsa-sha2-512`
  - `ecdsa-sha2-nistp256`
  - `ecdsa-sha2-nistp384`
  - `ecdsa-sha2-nistp521`
- Authentication:
  - `none`
  - `password`
  - `publickey`
- Compression:
  - `none`
  - `zlib@openssh.com`
- Channels:
  - `session`
  - `direct-tcpip`
  - `forwarded-tcpip`
  - `x11`
- Other: - Strict key exchange (KEX) - `server-sig-algs` extension - `ping@openssh.com` extension - OpenSSH keepalive handling.
</details>

## Why SSH?

When we think about SSH, we almost exclusively think of it as a tool for remote shell access — `ssh user@server` and you're accessing a remote machine. But SSH is a _protocol_, not just a tool. Like HTTP, and it comes with some really nice benefits out of the box:

- **Encrypted by default** — No certificates to manage, no HTTPS setup
- **Built-in authentication** — Literally everyone and their mother has an SSH key
- **Universal client** — Everyone has a beautiful SSH client already
- **Terminal-native** — We've all got a terminal

You can build all kinds of things over SSH: git servers, file browsers, and even [coffee shops](https://terminal.shop).

Crussh is a library for building these kinds of things in Ruby.

## Installation

Add to your Gemfile:

```ruby
gem "crussh"
```

## Quick Start

```ruby
require "crussh"

class HelloHandler < Crussh::Handler
  before :log_connect
  after :log_disconnect

  def handle
    puts "Hello, #{user}!"
    puts "Your terminal is #{pty&.term || "unknown"}"

    exit_status(0)
    close
  end

  private

  def log_connect
    logger.info("Client connected", user:)
  end

  def log_disconnect
    logger.info("Client disconnected", user:)
  end
end

class HelloServer < Crussh::Server
  configure do |c|
    c.port = 2222

    # Automatically generate host keys
    c.generate_host_keys!

    # OR load from a file
    # c.host_key_files << "/path/to/host_key"
  end

  authenticate(:none) { true }

  handle :shell, HelloHandler
end

Sync { HelloServer.run }
```

Connect with any SSH client:

```bash
ssh localhost -p 2222
# => Hello, yourname!
# => Your terminal is xterm-256color
```

## Features

- **No OpenSSH** — No OpenSSH dependency. Runs anywhere Ruby runs.
- **Modern cryptography** — ChaCha20-Poly1305, Curve25519, Ed25519 by default
- **Async-native** — Built on [Async](https://github.com/socketry/async) for concurrent connections and channels
- **Clean DSL** — Rails-inspired configuration and authentication
- **Handler-based** — Separate classes for shell, exec, and subsystem requests
- **Low-level access** — Drop down to raw channel I/O when you need control

## Authentication

Crussh currently supports `none`, `password` and `publickey` auth. `keyboard-interactive` is planned — PRs welcome!

```ruby
class MyServer < Crussh::Server
  authenticate(:none) { |username| username == "guest" }

  authenticate(:password) do |username, password|
    Users.authenticate(username, password)
  end

  authenticate(:publickey) do |username, key|
    AuthorizedKeys.include?(username, key.fingerprint)
  end
end
```

## Handlers

Handlers are plain Ruby classes that process SSH requests. They inherit from `Crussh::Handler` and give you a clean, testable way to organize your logic:

```ruby
class ShellHandler < Crussh::Handler
  def handle
    puts "Welcome, #{user}!"
    puts "Type 'exit' to quit."

    each_line(prompt: "$ ") do |line|
      break if line == "exit"

      puts "You typed: #{line}"
    end

    exit_status(0)
    close
  end
end

class ExecHandler < Crussh::Handler
  def setup(command)
    @command = command
  end

  def handle
    IO.popen(@command, err: [:child, :out]) do |io|
      IO.copy_stream(io, channel)
    end

    exit_status($CHILD_STATUS.exitstatus)
    close
  end
end

class MyServer < Crussh::Server
  configure do |c|
    c.port = 2222
    c.generate_host_keys!
  end

  authenticate(:publickey) { |user, key| authorized?(user, key) }

  handle :shell, ShellHandler
  handle :exec, ExecHandler
end
```

Handlers have access to:

- `user` — the authenticated username
- `pty` — PTY info (term, width, height) if requested
- `env` — environment variables from the client
- `channel` — the underlying channel for advanced use
- I/O methods: `puts`, `print`, `gets`, `read`, `write`
- Lifecycle: `close`, `send_eof`, `exit_status`, `exit_signal`

### Callbacks

Handlers support Rails-style lifecycle callbacks:

```ruby
class MyHandler < Crussh::Handler
  before :setup_environment
  after :cleanup
  around :with_timing

  rescue_from IOError, with: :handle_disconnect

  def handle
    # ...
  end

  private

  def with_timing
    start = Time.now
    yield
  ensure
    logger.debug("Duration", seconds: Time.now - start)
  end
end
```

## Input Handling

Crussh provides three levels of abstraction for reading events on the channel:

```ruby
class MyHandler < Crussh::Handler
  def handle
    # Low-level: raw SSH events
    each_event do |event|
      case event
      in Channel::Data(data:)
        # raw bytes from client
      in Channel::WindowChange(width:, height:)
        # terminal resized
      in Channel::EOF
        # client sent EOF
      end
    end

    # Mid-level: parsed keystrokes
    each_key do |key|
      case key
      when :arrow_up then move_up
      when :enter then submit
      when String then insert(key)
      end
    end

    # High-level: line editing with prompt
    each_line(prompt: "> ") do |line|
      process(line)
    end
  end

  # Called automatically by each_key/each_line on window resize
  def resize(width, height)
    @width = width
    @height = height
    redraw
  end
end
```

## Configuration

```ruby
class MyServer < Crussh::Server
  configure do |c|
    # Network
    c.host = "0.0.0.0"
    c.port = 2222

    # Keys (generate or load from files)
    c.generate_host_keys!
    # c.host_key_files << "/path/to/ssh_host_ed25519_key"

    c.max_connections = 100
    c.max_auth_attempts = 6

    c.connection_timeout = 10
    c.auth_timeout = 30
    c.inactivity_timeout = 600

    c.keepalive_interval = 30
    c.keepalive_max = 3
  end
end
```

## Pro Tips

### Development SSH Config

When developing locally, add this to `~/.ssh/config` to avoid `known_hosts` conflicts:

```
Host localhost
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
```

### How It Works

Crussh implements the SSH protocol from scratch using Ruby and a small Rust extension for Poly1305. OpenSSH is never involved — you can uninstall it entirely if you want.

Because there's no default shell behavior, there's no risk of accidentally exposing system access. Your server only does what you explicitly implement.

## Running with systemd

For production deployments, create a systemd unit file:

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My SSH App
After=network.target

[Service]
Type=simple
User=myapp
Group=myapp
WorkingDirectory=/home/myapp
ExecStart=/usr/bin/ruby /home/myapp/server.rb
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Then:

```bash
# Create a dedicated user
sudo useradd --system --user-group --create-home myapp

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable myapp
sudo systemctl start myapp
```

## Documentation

_Coming soon_

- Getting Started
- Configuration Reference
- Authentication Guide
- Writing Handlers
- API Reference

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MSILycanthropy/crussh.

## License

[MIT](LICENSE.txt)

---

Crussh is inspired by [russh](https://github.com/warp-tech/russh) (Rust) and [Wish](https://github.com/charmbracelet/wish) (Go). Built on [Async](https://github.com/socketry/async) for Ruby's concurrent future.
