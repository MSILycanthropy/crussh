# frozen_string_literal: true

module Crussh
  class Handler
    class LineBuffer
      def initialize(channel, echo: true)
        @channel = channel
        @buffer = +""
        @cursor = 0
        @echo = echo
      end

      attr_reader :buffer

      def handle(key)
        case key
        when String
          insert(key)
        when :backspace
          backspace
        when :delete
          delete
        when :arrow_left
          move_left
        when :arrow_right
          move_right
        when :home
          move_to_start
        when :end
          move_to_end
        end
      end

      def flush
        line = @buffer
        @buffer = +""
        @cursor = 0
        line
      end

      def clear
        if @echo && @buffer.length.positive?
          move_to_start
          @channel.print("\e[K")
        end

        @buffer = +""
        @cursor = 0
      end

      private

      def cursor_at_start?
        @cursor.zero?
      end

      def cursor_at_end?
        @cursor == @buffer.length
      end

      def insert(char)
        if cursor_at_end?
          @buffer << char
          @cursor += 1
          @channel.print(char) if @echo
          return
        end

        @buffer.insert(@cursor, char)
        @cursor += 1
        redraw_from_cursor if @echo
      end

      def backspace
        return if cursor_at_start?

        @cursor -= 1
        @buffer.slice!(@cursor)

        if @echo
          @channel.print("\b")
          redraw_from_cursor
        end
      end

      def delete
        return if cursor_at_end?

        @buffer.slice!(@cursor)
        redraw_from_cursor if @echo
      end

      def move_left
        return if cursor_at_start?

        @cursor -= 1
        @channel.print("\e[D") if @echo
      end

      def move_right
        return if cursor_at_end?

        @cursor += 1
        @channel.print("\e[C") if @echo
      end

      def move_to_start
        return if cursor_at_start?

        @channel.print("\e[#{@cursor}D") if @echo && @cursor > 0
        @cursor = 0
      end

      def move_to_end
        return if cursor_at_end?

        distance = @buffer.length - @cursor
        @channel.print("\e[#{distance}C") if @echo && distance > 0
        @cursor = @buffer.length
      end

      def redraw_from_cursor
        rest = @buffer[@cursor..]

        @channel.print(rest)
        @channel.print("\e[K")
        @channel.print("\e[#{rest.length}D") if rest.empty?
      end
    end
  end
end
