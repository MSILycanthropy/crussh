# frozen_string_literal: true

require "io/stream"

module Crussh
  module Transport
    class PacketStream
      MIN_PADDING = 4
      MAX_PADDING = 255
      MIN_PACKET_SIZE = 5

      BLOCK_SIZE = 8

      def initialize(socket, max_packet_size:)
        @stream = IO::Stream(socket)
        @reader = Reader.new(@stream, max_packet_size)
        @writer = Writer.new(@stream)
      end

      def read
        @reader.read
      end

      def write(data)
        @writer.write(data)
      end

      def enable_encryption(opening_key, sealing_key)
        @reader.enable_encryption(opening_key)
        @writer.enable_encryption(sealing_key)
      end

      def last_read_sequence
        @reader.last_sequence
      end

      class Writer
        def initialize(stream)
          @stream = stream
          @sequence = 0
          @sealing_key = nil
        end

        def encrypted?
          !@sealing_key.nil?
        end

        def write(data)
          if encrypted?
            write_encrypted(data)
          else
            write_unencrypted(data)
          end

          increment_sequence
        end

        def enable_encryption(sealing_key)
          @sealing_key = sealing_key
        end

        private

        def increment_sequence
          @sequence = (@sequence + 1) & 0xFFFFFFFF
        end

        def write_encrypted(data)
          padded = pad(data)

          length_bytes = [padded.bytesize].pack("N")
          encrypted_length = @sealing_key.encrypt_length(@sequence, length_bytes)

          ciphertext, tag = @sealing_key.seal(@sequence, encrypted_length, padded)

          @stream.write(encrypted_length + ciphertext + tag)
        end

        def write_unencrypted(data)
          padded = pad(data)
          packet = [padded.bytesize].pack("N") + padded

          @stream.write(packet)
        end

        def pad(data)
          data = data.b
          payload_length = data.bytesize

          min_total = 1 + payload_length + MIN_PADDING
          min_total += 4 unless encrypted?

          extra = (BLOCK_SIZE - (min_total % BLOCK_SIZE)) % BLOCK_SIZE
          padding_length = MIN_PADDING + extra

          padding_bytes = SecureRandom.random_bytes(padding_length)

          [padding_length].pack("C") + data + padding_bytes
        end
      end

      class Reader
        def initialize(stream, max_packet_size)
          @stream = stream
          @max_packet_size = max_packet_size

          @sequence = 0
          @last_sequence = 0
        end

        attr_reader :last_sequence

        def encrypted?
          !@opening_key.nil?
        end

        def read
          @last_sequence = @sequence

          result = if encrypted?
            read_encrypted
          else
            read_unencrypted
          end

          increment_sequence

          result
        end

        def enable_encryption(opening_key)
          @opening_key = opening_key
        end

        private

        def increment_sequence
          @sequence = (@sequence + 1) & 0xFFFFFFFF
        end

        def read_unencrypted
          length_bytes = @stream.read_exactly(4)
          packet_length = length_bytes.unpack1("N")

          validate_packet_length!(packet_length)

          data = @stream.read_exactly(packet_length)

          unwrap(data)
        end

        def read_encrypted
          encrypted_length = @stream.read_exactly(4)

          length_bytes = @opening_key.decrypt_length(@sequence, encrypted_length)
          packet_length = length_bytes.unpack1("N")

          validate_packet_length!(packet_length)

          ciphertext = @stream.read_exactly(packet_length)
          tag = @stream.read_exactly(16)

          plaintext = @opening_key.open(@sequence, encrypted_length, ciphertext, tag)

          unwrap(plaintext)
        end

        def unwrap(data)
          return if data.empty?

          padding_length = data.getbyte(0)

          validate_padding_length!(padding_length, data.bytesize)

          payload_length = data.bytesize - padding_length - 1

          validate_payload_length!(payload_length)

          data.byteslice(1, payload_length)
        end

        def validate_packet_length!(packet_length)
          if packet_length < MIN_PACKET_SIZE
            raise PacketTooSmall, "Packet length #{packet_length} below minimum #{MIN_PACKET_SIZE}"
          end

          return if packet_length <= @max_packet_size

          raise PacketTooLarge, "Packet length #{packet_length} exceeds maximum #{@max_packet_size}"
        end

        def validate_padding_length!(padding_length, packet_length)
          if padding_length < MIN_PADDING
            raise InvalidPadding, "Padding length #{padding_length} below minimum #{MIN_PADDING}"
          end

          if padding_length > MAX_PADDING
            raise InvalidPadding, "Padding length #{padding_length} exceeds maximum #{MAX_PADDING}"
          end

          return if padding_length < packet_length

          raise InvalidPadding, "Padding length #{padding_length} >= packet length #{packet_length}"
        end

        def validate_payload_length!(payload_length)
          raise PacketTooSmall, "Invalid payload length: #{payload_length}" if payload_length.negative?
        end
      end
    end
  end
end
