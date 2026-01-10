# frozen_string_literal: true

module Crussh
  class Channel
    module Keys
      ENTER     = :enter
      INTERRUPT = :interrupt
      EOF       = :eof
      BACKSPACE = :backspace
      DELETE    = :delete
      TAB       = :tab

      ARROW_UP    = :arrow_up
      ARROW_DOWN  = :arrow_down
      ARROW_LEFT  = :arrow_left
      ARROW_RIGHT = :arrow_right

      HOME      = :home
      END_KEY   = :end
      PAGE_UP   = :page_up
      PAGE_DOWN = :page_down
      INSERT    = :insert
    end

    class KeyParser
      ESCAPE = "\e"
      ESCAPE_SEQUENCES = {
        "[A" => Keys::ARROW_UP,
        "[B" => Keys::ARROW_DOWN,
        "[C" => Keys::ARROW_RIGHT,
        "[D" => Keys::ARROW_LEFT,
        "[H" => Keys::HOME,
        "[F" => Keys::END_KEY,
        "[1~" => Keys::HOME,
        "[4~" => Keys::END_KEY,
        "[2~" => Keys::INSERT,
        "[3~" => Keys::DELETE,
        "[5~" => Keys::PAGE_UP,
        "[6~" => Keys::PAGE_DOWN,
        "OH" => Keys::HOME,
        "OF" => Keys::END_KEY,
      }
      MAX_ESCAPE_LENGTH = 8

      def initialize
        @escape_buffer = +""
      end

      def parse(data)
        keys = []

        data.each_char do |char|
          if @escape_buffer.empty?
            if char == ESCAPE
              @escape_buffer = +ESCAPE
            else
              key = parse_char(char)
              keys << key if key
            end
          else
            @escape_buffer << char

            if complete_escape?
              key = resolve_escape
              keys << key if key
              @escape_buffer = +""
            elsif @escape_buffer.length >= MAX_ESCAPE_LENGTH
              @escape_buffer = +""
            end
          end
        end

        keys
      end

      def flush
        return if @escape_buffer.empty?

        key = @escape_buffer == ESCAPE ? :escape : nil
        @escape_buffer = ""
        key
      end

      private

      def parse_char(char)
        case char
        when "\r", "\n"
          Keys::ENTER
        when "\t"
          Keys::TAB
        when "\u0003"  # Ctrl+C
          Keys::INTERRUPT
        when "\u0004"  # Ctrl+D
          Keys::EOF
        when "\u007F", "\b" # DEL and BS
          Keys::BACKSPACE
        else
          char if char.ord >= 32
        end
      end

      def complete_escape?
        return false if @escape_buffer.length < 2

        sequence = @escape_buffer[1..]

        if sequence.start_with?("[")
          return sequence.length > 1 && sequence[-1].match?(/[A-Za-z~]/)
        end

        if sequence.start_with?("O")
          return sequence.length == 2 && sequence[-1].match?(/[A-Za-z]/)
        end

        sequence >= 2
      end

      def resolve_escape
        sequence = @escape_buffer[1..]
        ESCAPE_SEQUENCES[sequence]
      end
    end
  end
end
