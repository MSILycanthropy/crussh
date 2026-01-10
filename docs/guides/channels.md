# Channels

Channels are the fundamental I/O abstraction in SSH. Each shell session, command execution, or port forward runs over its own channel. This guide covers direct channel access for advanced use cases.

Crussh is built on [Async](https://github.com/socketry/async), so all channel operations are non-blocking — they yield the current fiber while waiting, allowing other connections and channels to be processed concurrently.

## Accessing the Channel

Most of the time, you'll use the handler's delegated methods (`puts`, `gets`, `each_line`, etc.). Access the channel directly when you need:

```ruby
class MyHandler < Crussh::Handler
  def handle
    # Delegated (preferred for most cases)
    puts "Hello"

    # Direct access
    channel.write("Hello\r\n")
  end
end
```

## Reading

Read operations yield the fiber until data is available, allowing other connections to be processed concurrently.

`read(length = nil)`

Read bytes from the channel. Yields until data is available.

```ruby
# Read all available data until EOF
data = channel.read

# Read exactly 1024 bytes
chunk = channel.read(1024)
```

`readpartial(maxlen)`

Read up to `maxlen` bytes. Yields until at least some data is available. Raises `EOFError` at EOF.

```ruby
loop do
  chunk = channel.readpartial(4096)
  process(chunk)
rescue EOFError
  break
end
```

`gets(sep = $/, limit = nil)`

Read until separator (default: newline).

```ruby
line = channel.gets           # Read until \n
line = channel.gets("\r\n")   # Read until \r\n
line = channel.gets(nil, 100) # Read up to 100 bytes
```

`each`

Iterate over channel events, yields the fiber while waiting for more events:

```ruby
channel.each do |event|
  case event
  in Channel::Data(data:)
    process(data)
  in Channel::EOF
    break
  end
end
```

## Writing

`write(data)`

Write raw bytes. Returns number of bytes written.

```ruby
bytes = channel.write("Hello, world!")
```

`puts(*args)`

Write lines with appropriate line endings (`\n` or `\r\n` for PTY).

```ruby
channel.puts "Line 1", "Line 2"
channel.puts # Empty line
```

`print(*args)`

Write without trailing newline.

```ruby
channel.print("Enter name: ")
```

`<<(data)`

Chainable write.

```ruby
channel << "Hello " << "world!"
```

`flush`

Flush buffered writes. Usually not needed — writes are unbuffered.

```ruby
channel.flush
```

## Stderr

Write to the client's stderr stream:

```ruby
channel.stderr.puts "Warning: something happened"
channel.stderr.print("Error: ")
channel.stderr.write(error_details)
```

## Lifecycle

`send_eof`

Signal that you're done sending data. The channel remains open for reading.

```ruby
channel.write(response)
channel.send_eof # No more data from us
# Can still read from client
```

`close`

Close the channel completely.

```ruby
channel.exit_status(0)
channel.close
```

`exit_status(code)`

Send an exit code to the client. Call before `close`.

```ruby
channel.exit_status(0)   # Success
channel.exit_status(1)   # General error
channel.exit_status(127) # Command not found
```

`exit_signal(name, core_dumped:, message:)`

Signal that the process was terminated by a signal.

```ruby
channel.exit_signal("KILL", core_dumped: false, message: "Killed")
channel.close
```

## Channel State

`eof?`

Returns `true` if the client has sent EOF.

```ruby
process(channel.readpartial(4096)) until channel.eof?
```

`closed?`

Returns `true` if the channel is closed.

```ruby
return if channel.closed?

```

## Flow Control

SSH uses flow control to prevent fast senders from overwhelming slow receivers. Crussh handles this automatically, but you can observe it:

### Window Size

Each direction has a "window" — the number of bytes that can be sent before waiting for acknowledgment. When you write data, the window shrinks. As the receiver processes data, it sends window adjustments.

For most applications, you don't need to think about this. Writes will yield the fiber if the window is exhausted, resuming when the client acknowledges receipt.

### Large Transfers

For large data transfers, write in chunks:

```ruby
def send_file(path)
  File.open(path, "rb") do |file|
    while (chunk = file.read(32_768))
      channel.write(chunk)
    end
  end
  channel.send_eof
end
```

Crussh will handle flow control automatically, blocking writes if needed.

## Streaming with IO.copy_stream

For efficient data transfer, use Ruby's `IO.copy_stream`:

```ruby
class ExecHandler < Crussh::Handler
  def setup(command)
    @command = command
  end

  def handle
    IO.popen(@command, err: [:child, :out]) do |io|
      IO.copy_stream(io, channel)
    end

    channel.exit_status($CHILD_STATUS.exitstatus)
    channel.close
  end
end
```

## Binary Data

Channels handle binary data natively:

```ruby
class DownloadHandler < Crussh::Handler
  def setup(filename)
    @filename = filename
  end

  def handle
    path = safe_path(@filename)

    unless File.exist?(path)
      stderr.puts "File not found: #{@filename}"
      exit_status(1)
      close
      return
    end

    File.open(path, "rb") do |file|
      IO.copy_stream(file, channel)
    end

    exit_status(0)
    close
  end

  private

  def safe_path(filename)
    File.join("/allowed/path", File.basename(filename))
  end
end
```

## Concurrent Channel Operations

Channels are fiber-safe. You can read and write from different fibers:

```ruby
class BidirectionalHandler < Crussh::Handler
  def handle
    # Read from client, write to external service
    reader = Async do
      channel.each do |event|
        case event
        in Channel::Data(data:)
          @external.write(data)
        in Channel::EOF
          @external.close_write
          break
        end
      end
    end

    # Read from external service, write to client
    writer = Async do
      while (data = @external.read(4096))
        channel.write(data)
      end
      channel.send_eof
    end

    reader.wait
    writer.wait

    exit_status(0)
    close
  end
end
```

## PTY Considerations

When a PTY is allocated, the channel behaves slightly differently:

- Line endings are `\r\n` instead of `\n`
- Input may be line-buffered by the client
- Terminal escape sequences are meaningful

Check for PTY:

```ruby
if channel.pty?
  # Terminal mode
  channel.write("\e[2J") # Clear screen
else
  # Raw mode
  channel.write(binary_data)
end
```

## Environment Variables

Access client-requested environment variables:

```ruby
channel.env["LANG"]  # => "en_US.UTF-8"
channel.env["TERM"]  # => Usually set via PTY instead
```

Note: Environment variables must be explicitly accepted via [server configuration](configuration.md).

## Complete Example: File Transfer

A simple file upload/download handler:

```ruby
class FileHandler < Crussh::Handler
  def setup(command)
    @action, @path = command.split(" ", 2)
  end

  def handle
    case @action
    when "get" then send_file
    when "put" then receive_file
    else
      stderr.puts "Usage: get <path> | put <path>"
      exit_status(1)
      close
    end
  end

  private

  def send_file
    path = safe_path(@path)

    unless File.exist?(path)
      stderr.puts "Not found: #{@path}"
      exit_status(1)
      close
      return
    end

    File.open(path, "rb") do |f|
      IO.copy_stream(f, channel)
    end

    exit_status(0)
    close
  end

  def receive_file
    path = safe_path(@path)

    File.open(path, "wb") do |f|
      IO.copy_stream(channel, f)
    end

    stderr.puts "Saved: #{@path}"
    exit_status(0)
    close
  end

  def safe_path(path)
    base = File.expand_path("~/files")
    full = File.expand_path(File.join(base, path))

    unless full.start_with?(base)
      raise "Invalid path"
    end

    full
  end
end
```

## That's It!

You've completed the Crussh guide. For more details, check the [Reference](../reference/) documentation or browse the [Examples](../examples/).

Questions? Open an issue on [GitHub](https://github.com/MSILycanthropy/crussh).
