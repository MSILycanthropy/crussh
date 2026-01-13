# Getting Started

This guide will get you from zero to a working SSH server in about 5 minutes.

## Installation

Add Crussh to your Gemfile:

```ruby
gem "crussh"
```

Then run:

```bash
bundle install
```

## Your First Server

```ruby
require "crussh"

class HelloHandler < Crussh::Handler
  def handle
    puts "Hello, #{user}!"
    puts "You connected from a #{pty&.term || "non-terminal"} client."
    puts
    puts "Goodbye!"

    exit_status(0)
    close
  end
end

class HelloServer < Crussh::Server
  configure do |c|
    c.port = 2222
    c.generate_host_keys!
  end

  # Allow anyone to connect
  authenticate(:none) { true }

  handle :shell, HelloHandler
end

Sync { HelloServer.run }
```

Run it:

```bash
ruby server.rb
```

In another terminal, connect:

```bash
ssh localhost -p 2222
```

You should see:

```
Hello, yourname!
You connected from a xterm-256color client.

Goodbye!
Connection to localhost closed.
```

## What Just Happened?

Let's break it down!

### The Handler

```ruby
class HelloHandler < Crussh::Handler
  def handle
    puts "Hello, #{user}!"
    # ...
  end
end
```

Handlers process SSH requests. When a client opens a shell session, Crussh instantiates your handler and calls the `handle` method. Each handler has one channel it communicates over.

Inside the handler you get access to:

- `puts`, `print`, `gets`, `read`, `write` communicate with the client's terminal over the channel
- `user` returns the authenticated username
- `pty` contains terminal info (dimensions, term type) if the client requested a PTY
- `exit_status(code)` sends an exit code to the client
- `close` closes the channel

### The Server

```ruby
class HelloServer < Crussh::Server
  configure do |c|
    c.port = 2222
    c.generate_host_keys!
  end

  authenticate(:none) { true }

  handle :shell, HelloHandler
end
```

The server defines:

- **Configuration** — Port, host keys, timeouts, limits
- **Authentication** — Which auth methods to accept and how to validate them
- **Handlers** — Which classes handle shell, exec, and subsystem requests

### Running the Server

```ruby
Sync { HelloServer.run }
```

`Sync` comes from the [Async](https://github.com/socketry/async) gem. Crussh is async-native, so all servers run inside an async context.

## Adding Interactivity

Let's make it interactive. Update your handler:

```ruby
class ShellHandler < Crussh::Handler
  def handle
    puts "Welcome, #{user}!"
    puts "Type 'help' for commands, 'exit' to quit."
    puts


    puts "Goodbye!"
    exit_status(0)
    close
  end
end
```

## Adding Authentication

Open authentication is fine for development, but let's add the typical public key auth flow:

```ruby
class MyServer < Crussh::Server
  configure do |c|
    c.port = 2222
    c.generate_host_keys!
  end

  authenticate(:publickey) do |username, key|
    # Check against an authorized_keys file
    authorized_keys_path = File.expand_path("~/.ssh/authorized_keys")
    return false unless File.exist?(authorized_keys_path)

    File.readlines(authorized_keys_path).any? do |line|
      line.strip == key.to_authorized_key
    end
  end

  handle :shell, ShellHandler
end
```

Now only users with keys in your `~/.ssh/authorized_keys` can connect.

## Development Tips

### SSH Config

Add this to `~/.ssh/config` to avoid `known_hosts` noise during development:

```
Host localhost
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
```

### Verbose SSH

Use `-v` to see what's happening:

```bash
ssh -v localhost -p 2222
```

### Logging

Crussh uses the [Console](https://github.com/socketry/console) gem for logging. Set the log level:

```bash
CONSOLE_LEVEL=debug ruby server.rb
```

## Next Steps

- [Configuration](guides/configuration.md) — All the server options
- [Authentication](guides/authentication.md) — Password auth, multi-factor, and more
- [Handlers](guides/handlers.md) — Callbacks, error handling, and testing
