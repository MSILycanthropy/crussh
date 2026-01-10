# Input Handling

Crussh provides three levels of abstraction for reading input from the client. Choose based on how much control you need.

## Overview

| Level | Method | Use Case |
|-------|--------|----------|
| High | `each_line` | Line-based input with editing |
| Mid | `each_key` | Parsed keystrokes
| Low | `each_event` | Raw SSH events for full control |

## High Level: `each_line`

The simplest way to read input. Provides line editing with a prompt:

```ruby
class ShellHandler < Crussh::Handler
  def handle
    each_line(prompt: "> ") do |line|
      case line
      when "exit" then break
      when "help" then puts "Commands: help, exit"
      else puts "You typed: #{line}"
      end
    end

    exit_status(0)
    close
  end
end
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `prompt:` | `""` | String or Proc for the prompt |
| `echo:` | `true` | Whether to echo typed characters |

### Dynamic Prompts

Use a Proc for prompts that change:

```ruby
each_line(prompt: -> { "#{@cwd}> " }) do |line|
  # @cwd can change between lines
end
```

### Hidden Input

Disable echo:

```ruby
print "Password: "
each_line(echo: false) do |password|
  authenticate(password)
  break
end
```

### Built-in Features

`each_line` handles:

- Character echo (when enabled)
- Backspace and delete
- Cursor movement (arrow keys, home, end)
- Ctrl+C clears the line
- Ctrl+D exits the loop (returns `nil`)

### Window Resize

Define a `resize` method to handle terminal size changes:

```ruby
class ShellHandler < Crussh::Handler
  def handle
    @width = pty&.width || 80

    each_line(prompt: -> { build_prompt }) do |line|
      process(line)
    end
  end

  def resize(width, height)
    @width = width
    # Prompt will update on next line
  end

  private

  def build_prompt
    # Truncate prompt if terminal is narrow
    base = "#{user}@myapp:#{@cwd}"
    base.length > @width - 5 ? "> " : "#{base}> "
  end
end
```

## Mid Level: `each_key`

Parsed keystrokes — escape sequences resolved to symbols. Good for TUIS or other highly interactive applications:

```ruby
class MenuHandler < Crussh::Handler
  def handle
    @selected = 0
    @items = ["Option A", "Option B", "Option C"]
    render

    each_key do |key|
      case key
      when :arrow_up
        @selected = (@selected - 1) % @items.size
      when :arrow_down
        @selected = (@selected + 1) % @items.size
      when :enter
        choose(@items[@selected])
        break
      when "q", :eof
        break
      end
      render
    end

    exit_status(0)
    close
  end

  def resize(width, height)
    @width = width
    @height = height
    render
  end

  private

  def render
    print("\e[2J\e[H") # Clear screen, cursor home
    @items.each_with_index do |item, i|
      prefix = i == @selected ? "> " : "  "
      puts "#{prefix}#{item}"
    end
  end
end
```

### Key Symbols

| Symbol | Key |
|--------|-----|
| `:enter` | Enter / Return |
| `:backspace` | Backspace |
| `:delete` | Delete (forward) |
| `:arrow_up` | Up arrow |
| `:arrow_down` | Down arrow |
| `:arrow_left` | Left arrow |
| `:arrow_right` | Right arrow |
| `:home` | Home |
| `:end` | End |
| `:page_up` | Page Up |
| `:page_down` | Page Down |
| `:tab` | Tab |
| `:escape` | Escape |
| `:interrupt` | Ctrl+C |
| `:eof` | Ctrl+D |

Printable characters come through as single-character strings.

### Unknown Sequences

Unrecognized escape sequences are passed through as strings. You can handle or ignore them:

```ruby
each_key do |key|
  case key
  when Symbol then handle_special(key)
  when String then handle_char(key) if key.length == 1
  # Multi-char strings are unknown escape sequences — ignore
  end
end
```

## Low Level: `each_event`

Raw SSH channel events. Use when you need full control:

```ruby
class RawHandler < Crussh::Handler
  def handle
    each_event do |event|
      case event
      in Channel::Data(data:)
        process_data(data)

      in Channel::ExtendedData(data:, type:)
        process_extended(data, type)

      in Channel::WindowChange(width:, height:, pixel_width:, pixel_height:)
        handle_resize(width, height)

      in Channel::Signal(name:)
        handle_signal(name)

      in Channel::EOF
        break

      in Channel::Closed
        break
      end
    end

    exit_status(0)
    close
  end
end
```

### Event Types

| Event | Fields | Description |
|-------|--------|-------------|
| `Channel::Data` | `data:` | Raw bytes from client |
| `Channel::ExtendedData` | `data:`, `type:` | Extended data (e.g., stderr) |
| `Channel::WindowChange` | `width:`, `height:`, `pixel_width:`, `pixel_height:` | Terminal resized |
| `Channel::Signal` | `name:` | Signal sent by client |
| `Channel::EOF` | — | Client finished sending |
| `Channel::Closed` | — | Channel closed |

### Parsing Keys from Data Events

If you're using `each_event` but still want key parsing, use `each_key` on the Data event:

```ruby
each_event do |event|
  case event
  in Channel::Data
    event.each_key do |key|
      handle_key(key)
    end
  in Channel::WindowChange(width:, height:)
    handle_resize(width, height)
  in Channel::EOF | Channel::Closed
    break
  end
end
```

This gives you key parsing without the automatic resize hook.

## The `resize` Hook

When using `each_key` or `each_line`, window changes automatically call your `resize` method if defined:

```ruby
class MyHandler < Crussh::Handler
  def handle
    @width = pty&.width || 80
    @height = pty&.height || 24
    render

    each_key do |key|
      handle_key(key)
      render
    end
  end

  # Called automatically on window resize
  def resize(width, height)
    @width = width
    @height = height
    render
  end
end
```

With `each_event`, you handle `Channel::WindowChange` yourself.

## Choosing the Right Level

### Use `each_line` when:

- Building a command-line interface
- You want simple line-based input
- You don't need to handle individual keystrokes

### Use `each_key` when:

- Building a TUI (menus, games, editors)
- You need to respond to arrow keys, escape, etc.
- You want automatic resize handling

### Use `each_event` when:

- You need raw byte access
- You're implementing a protocol (e.g., file transfer)
- You need to handle signals or extended data
- You want full control over everything

## Complete Example: Text Editor

A simple line editor demonstrating `each_key`:

```ruby
class EditorHandler < Crussh::Handler
  def handle
    @lines = [""]
    @cursor_x = 0
    @cursor_y = 0
    @width = pty&.width || 80
    @height = pty&.height || 24

    render

    each_key do |key|
      case key
      when :arrow_up then move_cursor(0, -1)
      when :arrow_down then move_cursor(0, 1)
      when :arrow_left then move_cursor(-1, 0)
      when :arrow_right then move_cursor(1, 0)
      when :enter then insert_newline
      when :backspace then delete_back
      when :delete then delete_forward
      when :eof then break # Ctrl+D to exit
      when String then insert_char(key) if key.length == 1
      end

      render
    end

    exit_status(0)
    close
  end

  def resize(width, height)
    @width = width
    @height = height
    render
  end

  private

  def render
    print("\e[2J\e[H") # Clear and home
    @lines.first(@height - 1).each { |line| puts line }
    print("\e[#{@cursor_y + 1};#{@cursor_x + 1}H") # Position cursor
  end

  def insert_char(char)
    @lines[@cursor_y].insert(@cursor_x, char)
    @cursor_x += 1
  end

  def insert_newline
    rest = @lines[@cursor_y][@cursor_x..]
    @lines[@cursor_y] = @lines[@cursor_y][0...@cursor_x]
    @lines.insert(@cursor_y + 1, rest)
    @cursor_y += 1
    @cursor_x = 0
  end

  def delete_back
    if @cursor_x > 0
      @lines[@cursor_y].slice!(@cursor_x - 1)
      @cursor_x -= 1
    elsif @cursor_y > 0
      @cursor_x = @lines[@cursor_y - 1].length
      @lines[@cursor_y - 1] += @lines.delete_at(@cursor_y)
      @cursor_y -= 1
    end
  end

  def delete_forward
    if @cursor_x < @lines[@cursor_y].length
      @lines[@cursor_y].slice!(@cursor_x)
    elsif @cursor_y < @lines.length - 1
      @lines[@cursor_y] += @lines.delete_at(@cursor_y + 1)
    end
  end

  def move_cursor(dx, dy)
    @cursor_y = (@cursor_y + dy).clamp(0, @lines.length - 1)
    @cursor_x = (@cursor_x + dx).clamp(0, @lines[@cursor_y].length)
  end
end
```

## Next Steps

For advanced use cases, learn about direct channel access:

**Next: [Channels](channels.md)** — Low-level channel I/O and flow control
