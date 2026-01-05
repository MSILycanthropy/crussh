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
      end

      def read
        @reader.read
      end

      def write(data)
        @writer.write(data)
      end

      def set_negotiated_algorithms(algorithms:)
        raise NotImplementedError
      end

      class Writer
        def initialize(socket)
          @socket = socket

          @sequence = 0
        end

        def encrypted?
          return false if @algorithms.nil?

          algorithm = @algorithms.cipher_server_to_client

          return false if algorithm.nil?

          algorithm != "none"
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

        private

        def write_encrypted(data)
          raise NotImplementedError
        end

        def write_unencrypted(data)
          packet = pad_and_align(data)

          @socket.write(packet)
        end

        def pad_and_align(data)
          data = data.b
          payload_length = data.bytesize

          unpadded = 1 + MIN_PADDING + payload_length
          padding_length = (BLOCK_SIZE - (unpadded % BLOCK_SIZE)) % BLOCK_SIZE
          padding_length += BLOCK_SIZE if padding_length < MIN_PADDING

          padding_bytes = SecureRandom.random_bytes(padding_length)

          packet_length = 1 + payload_length + padding_length

          [packet_length].pack("N") +
            [padding_length].pack("C") +
            data +
            padding_bytes
        end
      end

      class Reader
        def initialize(socket, max_packet_size)
          @socket = socket
          @max_packet_size = max_packet_size

          @sequence = 0
        end

        def encrypted?
          return false if @algorithms.nil?

          algorithm = @algorithms.cipher_client_to_server

          return false if algorithm.nil?

          algorithm != "none"
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

        private

        def read_unencrypted
          length_bytes = read_bytes!(4)

          packet_length = length_bytes.unpack1("N")

          validate_packet_length!(packet_length)

          data = read_bytes!(packet_length)

          unwrap(data)
        end

        def read_encrypted_packet
          raise NotImplementedError
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
