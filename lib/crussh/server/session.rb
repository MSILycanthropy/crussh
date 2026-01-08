# frozen_string_literal: true

module Crussh
  class Server
    class Session
      def initialize(socket, config:, handler:)
        @socket = socket
        @config = config
        @handler = handler

        @packet_stream = Transport::PacketStream.new(socket, max_packet_size: config.max_packet_size)
      end

      attr_reader :client_version, :socket, :config, :handler, :packet_stream, :session_id

      def start
        transport = Layers::Transport.new(self)
        transport.run
        @session_id = transport.session_id

        userauth = Layers::Userauth.new(self)
        userauth.run
        @authenticated_user = userauth.authenticated_user

        Logger.info(self, "Session established", user: @authenticated_user)
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
    end
  end
end
