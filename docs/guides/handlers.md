# Handlers

Handlers process SSH channel requests — shell sessions, command execution, and subsystems. This guide covers how to write and register them.

## What Is a Handler?

A handler is any object that responds to `call(channel, session, *args)`. When a client makes a request, Crussh invokes your handler with:

- `channel` — The SSH channel for I/O
- `session` — The session object (contains `user`, config, etc.)
- `*args` — Additional arguments depending on request type:
  - Shell: none
  - Exec: `command` (String)
  - Subsystem: `name` (String)

This means you can use:

### A Lambda

```ruby
handle :shell, ->(channel, session) {
  channel.puts "Hello, #{session.user}!"
  channel.exit_status(0)
  channel.close
}
```

### Any Callable Object

```ruby
class MyCallable
  def call(channel, session)
    channel.puts "Hello from a callable!"
    channel.exit_status(0)
    channel.close
  end
end

handle :shell, MyCallable
```

### The Handler Base Class

For most cases, inherit from `Crussh::Handler`. It provides a clean DSL, lifecycle callbacks, and delegates I/O methods so you don't need to prefix everything with `channel.`:

```ruby
class ShellHandler < Crussh::Handler
  def handle
    puts "Hello, #{user}!"
    exit_status(0)
    close
  end
end

handle :shell, ShellHandler
```

The rest of this guide focuses on `Crussh::Handler`, but remember — anything callable works.

## Registering Handlers

Register handlers with the `handle` method in your Server configuration:

```ruby
class MyServer < Crussh::Server
  handle :shell, ShellHandler
  handle :exec, ExecHandler
  handle :subsystem, SftpHandler
end
```

### Request Types

| Type         | Triggered By            | Args      |
| ------------ | ----------------------- | --------- |
| `:shell`     | `ssh host`              | none      |
| `:exec`      | `ssh host "command"`    | `command` |
| `:subsystem` | `ssh -s host subsystem` | `name`    |

## Handler Lifecycle

When using `Crussh::Handler`, the lifecycle is:

```
initialize(channel, session)
↓
setup(*args)
↓
before callbacks
↓
around callbacks(wrap...
↓)
handle
↓
after callbacks # Always run, even on exception
```

### `setup`

Override `setup` to receive request-specific arguments:

```ruby
class ExecHandler < Crussh::Handler
  def setup(command)
    @command = command
  end

  def handle
    # Use @command
  end
end
```

### `handle`

Your main logic goes here. This is the only method you _must_ implement:

```ruby
class ShellHandler < Crussh::Handler
  def handle
    puts "Welcome!"
    # ...
    close
  end
end
```

## Context Methods

Inside a handler, you have access to:

| Method    | Description                               |
| --------- | ----------------------------------------- |
| `user`    | Authenticated username                    |
| `session` | The full session object                   |
| `channel` | The underlying channel (for advanced use) |
| `config`  | Server configuration                      |
| `pty`     | PTY info, or `nil` if no PTY requested    |
| `pty?`    | Whether a PTY was requested               |
| `env`     | Environment variables from the client     |
| `logger`  | Logger with session context               |

### PTY Info

When a client requests a pseudo-terminal, `pty` contains:

| Method         | Description                              |
| -------------- | ---------------------------------------- |
| `term`         | Terminal type (e.g., `"xterm-256color"`) |
| `width`        | Columns                                  |
| `height`       | Rows                                     |
| `pixel_width`  | Width in pixels (often 0)                |
| `pixel_height` | Height in pixels (often 0)               |
| `modes`        | Terminal modes (raw bytes)               |

## I/O Methods

The channel is a standard Ruby IO-like object. Use familiar methods to communicate with the client:

| Method                   | Description                          |
| ------------------------ | ------------------------------------ |
| `puts(*args)`            | Write lines (adds newline)           |
| `print(*args)`           | Write without newline                |
| `write(data)`            | Write raw bytes                      |
| `read(length = nil)`     | Read bytes                           |
| `gets(sep = "\n")`       | Read until separator                 |
| `readpartial(maxlen)`    | Read available bytes                 |
| `read_nonblock(len)`     | Non-blocking read                    |
| `wait_readable(timeout)` | Wait for input with optional timeout |

All I/O respects PTY settings — `puts` uses `\r\n` when a PTY is active.

## Channel Lifecycle

Control the channel state:

| Method                                      | Description              |
| ------------------------------------------- | ------------------------ |
| `close`                                     | Close the channel        |
| `send_eof`                                  | Send EOF without closing |
| `exit_status(code)`                         | Send exit code to client |
| `exit_signal(name, core_dumped:, message:)` | Send signal termination  |

Always send an exit status before closing:

```ruby
def handle
  # ... do work ...
  exit_status(0)
  close
end
```

## Resize and Signal Handling

Override these methods to respond to terminal resize and signals:

```ruby
class ShellHandler < Crussh::Handler
  def handle
    # ...
  end

  def handle_resize(width, height)
    # Called when client resizes terminal
    @terminal&.resize(height, width)
    redraw
  end

  def handle_signal(name)
    # Called when client sends a signal
    case name
    when "INT"
      # Handle Ctrl+C
    when "TERM"
      close
    end
  end
end
```

## Callbacks

Handlers support Rails-style lifecycle callbacks:

### `before`

Run before `handle`:

```ruby
class MyHandler < Crussh::Handler
  before :check_permissions
  before :load_user_settings

  def handle
    # ...
  end

  private

  def check_permissions
    close unless user_allowed?
  end

  def load_user_settings
    @settings = Settings.for(user)
  end
end
```

### `after`

Run after `handle`, even if an exception occurred:

```ruby
class MyHandler < Crussh::Handler
  after :cleanup
  after :log_completion

  def handle
    # ...
  end

  private

  def cleanup
    @temp_files&.each(&:delete)
  end

  def log_completion
    logger.info("Session ended", user:)
  end
end
```

### `around`

Wrap `handle` — must call `yield`:

```ruby
class MyHandler < Crussh::Handler
  around :with_timing
  around :with_error_boundary

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

  def with_error_boundary
    yield
  rescue => e
    logger.error("Unhandled error", error: e.message)
    puts "An error occurred. Please try again."
    exit_status(1)
    close
  end
end
```

### `rescue_from`

Handle specific exceptions:

```ruby
class MyHandler < Crussh::Handler
  rescue_from IOError, with: :handle_disconnect
  rescue_from CustomError do |e|
    puts "Error: #{e.message}"
    exit_status(1)
    close
  end

  def handle
    # ...
  end

  private

  def handle_disconnect(error)
    logger.info("Client disconnected", error: error.message)
  end
end
```

## Stderr

Write to the client's stderr:

```ruby
def handle
  puts "This goes to stdout"
  stderr.puts "This goes to stderr"
end
```

## Complete Example

```ruby
class ShellHandler < Crussh::Handler
  before :log_connect
  after :log_disconnect
  rescue_from IOError, with: :handle_disconnect

  def handle
    terminal = Vtx::Terminal.new(input: channel, output: channel)
    @terminal = terminal

    terminal.puts "Welcome, #{user}!"
    terminal.puts "Press 'q' to quit."
    terminal.flush

    terminal.each_event do |event|
      case event
      when Vtx::Events::Key(char: "q")
        break
      when Vtx::Events::Key(char:)
        terminal.puts "You pressed: #{char}"
        terminal.flush
      end
    end

    terminal.puts "Goodbye!"
    terminal.flush

    exit_status(0)
    close
  end

  def handle_resize(width, height)
    @terminal&.resize(height, width)
  end

  private

  def log_connect
    logger.info("Shell started", user:, term: pty&.term)
  end

  def log_disconnect
    logger.info("Shell ended", user:)
  end

  def handle_disconnect(error)
    logger.debug("Client disconnected", error: error.message)
  end
end
```

## Next Steps

- Learn about [VTX](https://github.com/example/vtx) for building terminal UIs
- See [Server Configuration](server.md) for authentication and request handling
