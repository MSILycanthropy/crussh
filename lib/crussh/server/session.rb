# frozen_string_literal: true

module Crussh
  class Server
    class Session
      def initialize(socket, server:)
        @socket = socket
        @server = server

        @packet_stream = Transport::PacketStream.new(socket, max_packet_size: config.max_packet_size)
      end

      attr_reader :client_version, :socket, :server, :user

      def config = @server.config

      def start
        transport = run_layer(Layers::Transport)
        @session_id = transport.session_id

        userauth = run_layer(Layers::Userauth)
        @user = userauth.authenticated_user

        run_layer(Layers::Connection)

        Logger.info(self, "Session established", user: @user)
      rescue StandardError => e
        Logger.error(self, "Error", e)
      ensure
        close
      end

      def close
        @socket.close unless @socket.closed?
      rescue StandardError => e
        Logger.error(self, "Error", e)
      end

      def host_key
        return if @algorithms.nil?

        @host_key ||= @config.host_keys.find { |key| key.algorithm == @algorithms.host_key }
      end

      def read_packet
        loop do
          packet = @packet_stream.read
          message_type = packet.getbyte(0)

          case message_type
          when Protocol::IGNORE
            next
          when Protocol::DEBUG
            message = Protocol::Debug.parse(packet)
            Logger.debug(self, "Client debug", message: message.message) if message.always_display
            next
          else
            return packet
          end
        end
      end

      def write_packet(message) = @packet_stream.write(message.serialize)
      def enable_encryption(...) = @packet_stream.enable_encryption(...)

      def last_read_sequence = @packet_stream.last_read_sequence

      private

      def run_layer(layer)
        instance = layer.new(self)
        instance.run
        instance
      end
    end
  end
end
