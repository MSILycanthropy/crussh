# frozen_string_literal: true

module Crussh
  module Transport
    class PacketStream
      MIN_PADDING = 4
      MAX_PADDING = 255
      MIN_PACKET_SIZE = 5 # 1 (padding_length) + 0 (payload) + 4 (min padding)

      BLOCK_SIZE = 8

      def initialize(socket, max_packet_size:)
        @socket = socket
        @max_packet_size = max_packet_size
        @cipher_in = nil
        @cipher_out = nil
      end

      def enable_encryption(cipher_in:, cipher_out:)
        @cipher_in = cipher_in
        @cipher_out = cipher_out
      end

      def read_encrypted?
        !@cipher_in.nil?
      end

      def write_encrypted?
        !@cipher_out.nil?
      end

      def read_packet
        return read_encrypted_packet if read_encrypted?

        read_unencrypted_packet
      end

      def write_packet(payload)
        return write_encrypted_packet(payload) if write_encrypted?

        write_unencrypted_packet(payload)
      end

      private

      def read_unencrypted_packet
        length_bytes = read_bytes!(4)

        packet_length = length_bytes.unpack1("N")

        validate_packet_length!(packet_length)

        data = read_bytes!(packet_length)

        unwrap(data)
      end

      def write_unencrypted_packet(payload)
        packet = wrap(payload)

        puts "DEBUG: packet_length=#{packet[0, 4].unpack1("N")} total_size=#{packet.bytesize}"

        @socket.write(packet)
      end

      def read_encrypted_packet
        raise NotImplementedError
      end

      def write_encrypted_packet
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

      def wrap(payload)
        payload = payload.b
        payload_length = payload.bytesize

        unpadded = 1 + MIN_PADDING + payload_length
        padding_length = (BLOCK_SIZE - (unpadded % BLOCK_SIZE)) % BLOCK_SIZE
        padding_length += BLOCK_SIZE if padding_length < MIN_PADDING

        padding_bytes = SecureRandom.random_bytes(padding_length)

        packet_length = 1 + payload_length + padding_length

        [packet_length].pack("N") +
          [padding_length].pack("C") +
          payload +
          padding_bytes
      end

      def align_to_block
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
