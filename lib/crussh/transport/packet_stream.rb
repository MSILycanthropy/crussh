# frozen_string_literal: true

module Crussh
  module Transport
    class PacketStream
      MIN_PADDING = 4
      MAX_PADDING = 255
      MIN_PACKET_SIZE = 5 # 1 (padding_length) + 0 (payload) + 4 (min padding)

      BLOCK_SIZE = 8

      def initialize(socket, max_packet_size:)
        @reader = Reader.new(socket, max_packet_size)
        @writer = Writer.new(socket)

        @opening_key = nil
        @sealing_key = nil
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

      class Writer
        def initialize(socket)
          @socket = socket
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

        def increment_sequence
          @sequence = (@sequence + 1) & 0xFFFFFFFF
        end

        def enable_encryption(sealing_key)
          @sealing_key = sealing_key
        end

        private

        def write_encrypted(data)
          padded = pad(data)

          length_bytes = [padded.bytesize].pack("N")
          encrypted_length = @sealing_key.encrypt_length(@sequence, length_bytes)

          ciphertext, tag = @sealing_key.seal(@sequence, encrypted_length, padded)

          @socket.write(encrypted_length + ciphertext + tag)
        end

        def write_unencrypted(data)
          padded = pad(data)
          packet = [padded.bytesize].pack("N") + padded

          @socket.write(packet)
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
        def initialize(socket, max_packet_size)
          @socket = socket
          @max_packet_size = max_packet_size

          @sequence = 0
        end

        def encrypted?
          !@opening_key.nil?
        end

        def read
          result = if encrypted?
            read_encrypted
          else
            read_unencrypted
          end

          increment_sequence

          result
        end

        def increment_sequence
          @sequence = (@sequence + 1) & 0xFFFFFFFF
        end

        def enable_encryption(opening_key)
          @opening_key = opening_key
        end

        private

        def read_unencrypted
          length_bytes = read_bytes!(4)

          packet_length = length_bytes.unpack1("N")

          validate_packet_length!(packet_length)

          data = read_bytes!(packet_length)

          unwrap(data)
        end

        def read_encrypted
          encrypted_length = read_bytes!(4)

          length_bytes = @opening_key.decrypt_length(@sequence, encrypted_length)
          packet_length = length_bytes.unpack1("N")

          ciphertext = read_bytes!(packet_length)
          tag = read_bytes!(16)

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

        def read_bytes!(n)
          data = @socket.read(n)

          if data.nil?
            raise ConnectionClosed, "Connection closed"
          end

          if data.bytesize < n
            raise ConnectionClosed, "Connection closed (got #{data.bytesize}/#{n} bytes)"
          end

          data
        end

        def validate_packet_length!(packet_length)
          if packet_length < MIN_PACKET_SIZE
            raise PacketTooSmall, "Packet length #{packet_length} below minimum #{MIN_PACKET_SIZE}"
          end

          if packet_length > @max_packet_size
            raise PacketTooLarge, "Packet length #{packet_length} exceeds absolute maximum"
          end

          return if packet_length <= @max_packet_size

          raise PacketTooLarge, "Packet length #{packet_length} exceeds configured maximum #{@max_packet_size}"
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
