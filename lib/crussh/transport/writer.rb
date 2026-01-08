# frozen_string_literal: true

module Crussh
  module Transport
    class Writer
      def initialize
        @buffer = String.new(encoding: Encoding::BINARY, capacity: 256)
      end

      def byte(value)
        @buffer << [value].pack("C")
        self
      end

      def boolean(value)
        byte(value ? 1 : 0)
      end

      def uint32(value)
        @buffer << [value].pack("N")
        self
      end

      def string(value)
        value = value.b if value.is_a?(String)
        uint32(value.bytesize)
        @buffer << value
        self
      end

      def name_list(names)
        string(names.join(","))
      end

      def raw(bytes)
        @buffer << bytes
        self
      end

      def remaining(value)
        raw(value.b)
        self
      end

      def mpint(bn)
        bn = OpenSSL::BN.new(bn) if bn.is_a?(Integer)

        return uint32(0) if bn.zero?

        raw_bytes = bn.to_s(2)

        # two's compliment moment
        raw_bytes = "\u0000#{raw_bytes}" if raw_bytes.getbyte(0) & 0x80 != 0

        string(raw_bytes)
      end

      def to_s
        @buffer.dup
      end

      def length
        @buffer.bytesize
      end

      def reset
        @buffer.clear
        self
      end
    end
  end
end
