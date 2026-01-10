# frozen_string_literal: true

module Crussh
  module Transport
    class Reader
      def initialize(data)
        @data = data.b
        @position = 0
      end

      def byte
        ensure_remaining!(1)

        value = @data.getbyte(@position)

        @position += 1

        value
      end

      def boolean
        byte != 0
      end

      def uint32
        ensure_remaining!(4)

        value = @data[@position, 4].unpack1("N")

        @position += 4

        value
      end

      def string(max_length: nil)
        length = uint32

        raise PacketTooLarge, "String length #{length} exceeds maximum #{max_length}" if max_length && length > max_length

        ensure_remaining!(length)

        value = @data[@position, length]

        @position += length

        value
      end

      def read(n)
        ensure_remaining!(n)

        value = @data[@position, n]

        @position += n

        value
      end

      def mpint
        raw = string

        return OpenSSL::BN.new(0) if raw.empty?

        OpenSSL::BN.new(raw, 2)
      end

      def name_list
        string.split(",")
      end

      def remaining
        @data.byteslice(@position..)
      end

      def remaining_bytes
        @data.bytesize - @position
      end

      def skip(n)
        ensure_remaining!(n)

        @position += n
      end

      def eof?
        @position >= @data.bytesize
      end

      private

      def ensure_remaining!(n)
        return if @position + n <= @data.bytesize

        raise IncompletePacket, "Need #{n} bytes but only #{remaining_bytes} available"
      end
    end
  end
end
