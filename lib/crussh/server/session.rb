# frozen_string_literal: true

module Crussh
  class Server
    class Session
      attr_reader :client_version

      def initialize(socket, config:, handler:)
        @socket = socket
        @config = config
        @handler = handler

        @packet_stream = Transport::PacketStream.new(socket, max_packet_size: config.max_packet_size)

        @client_version = nil
        @algorithms = nil

        @client_kexinit_payload = nil
        @server_kexinit_payload = nil
      end

      def start
        version_exchange
        algorithm_negotiation

        puts "[crussh] Handshake complete"
      rescue ProtocolError => e
        puts "[crussh] Protocol error: #{e.message}"
      rescue ConnectionClosed => e
        puts "[crussh] Connection closed: #{e.message}"
      rescue StandardError => e
        puts "[crussh] Error: #{e.class}: #{e.message}"
        puts e.backtrace.first(5).join("\n")
      ensure
        close
      end

      def close
        @socket.close unless @socket.closed?
      rescue StandardError => e
        puts "[crussh] Error: #{e.class}: #{e.message}"
        puts e.backtrace.first(5).join("\n")
      end

      private

      def version_exchange
        exchange = Transport::VersionExchange.new(@socket, server_id: @config.server_id)

        @client_version = exchange.exchange

        puts "[crussh] Client version: #{@client_version.software_version}"
        return unless @client_version.comments

        puts "[crussh]   Comments: #{@client_version.comments}"
      end

      def algorithm_negotiation
        @client_kexinit_payload = @packet_stream.read

        client_kexinit = Kex::Init.parse(@client_kexinit_payload)

        puts "[crussh] Client KEXINIT received"
        puts "[crussh]   kex: #{client_kexinit.kex_algorithms.join(", ")}"
        puts "[crussh]   host_key: #{client_kexinit.server_host_key_algorithms.join(", ")}"
        puts "[crussh]   cipher: #{client_kexinit.cipher_client_to_server.first(3).join(", ")}..."

        server_kexinit = Kex::Init.from_preferred(@config.preferred)
        @server_kexinit_payload = server_kexinit.serialize
        @packet_stream.write(@server_kexinit_payload)

        puts "[crussh] Server KEXINIT sent"

        @algorithms = Negotiator.new(client_kexinit, server_kexinit).negotiate

        puts "[crussh] Negotiated algorithms:"
        puts "  kex: #{@algorithms.kex}"
        puts "  host_key: #{@algorithms.kex}"
        puts "  cipher_client_to_server: #{@algorithms.cipher_client_to_server}"
        puts "  cipher_server_to_client: #{@algorithms.cipher_server_to_client}"
        puts "  mac_client_to_server: #{@algorithms.mac_client_to_server}"
        puts "  mac_server_to_client: #{@algorithms.mac_server_to_client}"
        puts "  compression_client_to_server: #{@algorithms.compression_client_to_server}"
        puts "  compression_server_to_client: #{@algorithms.compression_server_to_client}"
      end
    end
  end
end
