# frozen_string_literal: true

module Crussh
  class Server
    class Session
      def initialize(socket, server:)
        @socket = socket
        @server = server

        @packet_stream = Transport::PacketStream.new(socket, max_packet_size: config.max_packet_size)

        @bytes_read = 0
        @bytes_written = 0
        @last_kex_time = Time.now
        @algorithms = nil
      end

      attr_reader :client_version, :socket, :server, :user, :id
      attr_accessor :algorithms

      def config = @server.config

      def start
        transport = run_layer(Layers::Transport)
        @id = transport.session_id

        userauth = run_layer(Layers::Userauth)
        @user = userauth.authenticated_user

        run_layer(Layers::Connection)

        Logger.info(self, "Session established", user: @user)
      rescue NegotiationError => e
        Logger.error(self, "Negotation Error", e)
        disconnect(:key_exchange_failed, e.message)
      rescue ProtocolError => e
        Logger.error(self, "Protocol Error", e)
        disconnect(:protocol_error, e.message)
      rescue => e
        Logger.error(self, "Internal Server Error", e)
        disconnect(:by_application, "Internal error")
      ensure
        close
      end

      def disconnect(reason, description = "")
        message = Protocol::Disconnect.build(reason, description)
        write_raw_packet(message)
        close
      end

      def close
        return if socket.closed?

        @socket.close
      rescue StandardError => e
        Logger.error(self, "Error", e)
      end

      def host_key
        return if @algorithms.nil?

        @host_key ||= @config.host_keys.find { |key| key.algorithm == @algorithms.host_key }
      end

      def read_packet
        start_rekey if rekey?

        loop do
          packet = read_raw_packet
          message_type = packet.getbyte(0)

          case message_type
          when Protocol::IGNORE
            next
          when Protocol::DEBUG
            message = Protocol::Debug.parse(packet)
            Logger.debug(self, "Client debug", message: message.message) if message.always_display
            next
          when Protocol::KEXINIT
            rekey(packet)
            next
          else
            @bytes_read += packet.bytesize
            return packet
          end
        end
      end

      def write_packet(message)
        start_rekey if rekey?

        data = message.serialize
        @bytes_written += data.bytesize
        @packet_stream.write(data)
      end

      def read_raw_packet = @packet_stream.read
      def write_raw_packet(message) = @packet_stream.write(message.serialize)

      def enable_encryption(...) = @packet_stream.enable_encryption(...)

      def enable_compression
        return if @algorithms.nil?

        c2s = @algorithms.compression_client_to_server
        s2c = @algorithms.compression_server_to_client

        return if c2s == Compression::NONE && s2c == Compression::NONE

        read_compressor = Compression.from_name(c2s)
        write_compressor = Compression.from_name(s2c)

        @packet_stream.enable_compression(read_compressor, write_compressor)
        Logger.info(self, "Compression enabled", send: s2c, recv: c2s)
      end

      def last_read_sequence = @packet_stream.last_read_sequence

      private

      def rekey?
        limits = config.limits

        limits.over?(read: @bytes_read, written: @bytes_written, time: @last_kex_time)
      end

      def start_rekey
        Logger.info(self, "Initiating rekey to client")

        kex = Kex::Exchange.new(self)
        kex.start_rekey
        reset_rekey_tracking
      end

      def rekey(client_kexinit_payload)
        Logger.info(self, "Client initiated rekey")

        kex = Kex::Exchange.new(self)
        kex.rekey(client_kexinit_payload: client_kexinit_payload)

        Logger.info(self, "Rekey complete")
      end

      def reset_rekey_tracking
        @bytes_read = 0
        @bytes_written = 0
        @last_kex_time = Time.now
      end

      def run_layer(layer)
        instance = layer.new(self)
        instance.run
        instance
      end
    end
  end
end
