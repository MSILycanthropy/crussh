# frozen_string_literal: true

require "test_helper"

module Crussh
  class Channel
    class KeyParserTest < Minitest::Test
      def setup
        @parser = KeyParser.new
      end

      # --- Printable characters ---

      def test_printable_characters
        keys = @parser.parse("hello")
        assert_equal(["h", "e", "l", "l", "o"], keys)
      end

      def test_space
        keys = @parser.parse(" ")
        assert_equal([" "], keys)
      end

      def test_numbers_and_symbols
        keys = @parser.parse("123!@#")
        assert_equal(["1", "2", "3", "!", "@", "#"], keys)
      end

      # --- Control characters ---

      def test_enter_cr
        keys = @parser.parse("\r")
        assert_equal([:enter], keys)
      end

      def test_enter_lf
        keys = @parser.parse("\n")
        assert_equal([:enter], keys)
      end

      def test_tab
        keys = @parser.parse("\t")
        assert_equal([:tab], keys)
      end

      def test_ctrl_c
        keys = @parser.parse("\u0003")
        assert_equal([:interrupt], keys)
      end

      def test_ctrl_d
        keys = @parser.parse("\u0004")
        assert_equal([:eof], keys)
      end

      def test_backspace_del
        keys = @parser.parse("\u007F")
        assert_equal([:backspace], keys)
      end

      def test_backspace_bs
        keys = @parser.parse("\b")
        assert_equal([:backspace], keys)
      end

      # --- Arrow keys ---

      def test_arrow_up
        keys = @parser.parse("\e[A")
        assert_equal([:arrow_up], keys)
      end

      def test_arrow_down
        keys = @parser.parse("\e[B")
        assert_equal([:arrow_down], keys)
      end

      def test_arrow_right
        keys = @parser.parse("\e[C")
        assert_equal([:arrow_right], keys)
      end

      def test_arrow_left
        keys = @parser.parse("\e[D")
        assert_equal([:arrow_left], keys)
      end

      # --- Navigation keys ---

      def test_home
        keys = @parser.parse("\e[H")
        assert_equal([:home], keys)
      end

      def test_home_alternate
        keys = @parser.parse("\e[1~")
        assert_equal([:home], keys)
      end

      def test_home_xterm
        keys = @parser.parse("\eOH")
        assert_equal([:home], keys)
      end

      def test_end
        keys = @parser.parse("\e[F")
        assert_equal([:end], keys)
      end

      def test_end_alternate
        keys = @parser.parse("\e[4~")
        assert_equal([:end], keys)
      end

      def test_end_xterm
        keys = @parser.parse("\eOF")
        assert_equal([:end], keys)
      end

      def test_delete
        keys = @parser.parse("\e[3~")
        assert_equal([:delete], keys)
      end

      def test_page_up
        keys = @parser.parse("\e[5~")
        assert_equal([:page_up], keys)
      end

      def test_page_down
        keys = @parser.parse("\e[6~")
        assert_equal([:page_down], keys)
      end

      def test_insert
        keys = @parser.parse("\e[2~")
        assert_equal([:insert], keys)
      end

      # --- Mixed input ---

      def test_mixed_input
        keys = @parser.parse("ab\e[Acd")
        assert_equal(["a", "b", :arrow_up, "c", "d"], keys)
      end

      def test_text_then_enter
        keys = @parser.parse("hello\r")
        assert_equal(["h", "e", "l", "l", "o", :enter], keys)
      end

      def test_multiple_escape_sequences
        keys = @parser.parse("\e[A\e[B\e[C")
        assert_equal([:arrow_up, :arrow_down, :arrow_right], keys)
      end

      # --- Stateful parsing (escape buffer) ---

      def test_escape_sequence_split_across_calls
        keys1 = @parser.parse("\e")
        assert_equal([], keys1)

        keys2 = @parser.parse("[A")
        assert_equal([:arrow_up], keys2)
      end

      def test_escape_sequence_split_multiple
        keys1 = @parser.parse("\e[")
        assert_equal([], keys1)

        keys2 = @parser.parse("A")
        assert_equal([:arrow_up], keys2)
      end

      # --- Edge cases ---

      def test_empty_input
        keys = @parser.parse("")
        assert_equal([], keys)
      end

      def test_unknown_escape_sequence_discarded
        keys = @parser.parse("\e[Z")
        assert_equal([], keys)
      end

      def test_control_characters_below_space_ignored
        keys = @parser.parse("\u0001\u0002")
        assert_equal([], keys)
      end
    end

    class DataEachKeyTest < Minitest::Test
      def test_each_key_yields_parsed_keys
        data = Data.new(data: "ab\r")
        keys = []

        data.each_key { |k| keys << k }

        assert_equal(["a", "b", :enter], keys)
      end

      def test_each_key_returns_enumerator
        data = Data.new(data: "abc")
        enum = data.each_key

        assert_kind_of(Enumerator, enum)
        assert_equal(["a", "b", "c"], enum.to_a)
      end

      def test_each_key_with_escape_sequence
        data = Data.new(data: "\e[Ax")
        keys = data.each_key.to_a

        assert_equal([:arrow_up, "x"], keys)
      end
    end
  end
end
