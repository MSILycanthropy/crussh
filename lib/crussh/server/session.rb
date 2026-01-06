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
        key_exchange

        puts "[crussh] Handshake complete"

        service_request
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

      def host_key
        return if @algorithms.nil?

        @host_key ||= @config.host_keys.find { |key| key.algorithm == @algorithms.host_key }
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

        client_kexinit = Protocol::KexInit.parse(@client_kexinit_payload)

        puts "[crussh] Client KEXINIT received"
        puts "[crussh]   kex: #{client_kexinit.kex_algorithms.join(", ")}"
        puts "[crussh]   host_key: #{client_kexinit.server_host_key_algorithms.join(", ")}"
        puts "[crussh]   cipher: #{client_kexinit.cipher_client_to_server.first(3).join(", ")}..."

        server_kexinit = Protocol::KexInit.from_preferred(@config.preferred)
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

      def key_exchange
        packet = @packet_stream.read
        kex_dh_init = Protocol::KexEcdhInit.parse(packet)
        client_public = kex_dh_init.public_key

        puts "[crussh] KEX_ECDH_INIT received (#{client_public.bytesize} bytes)"

        kex_algorithm = Kex.from_name(@algorithms.kex)
        server_public = kex_algorithm.server_dh_reply(client_public)

        puts "[crussh] Generated server public key (#{server_public.bytesize} bytes)"
        puts "[crussh] Shared secret computed"

        exchange = Kex::Exchange.new(
          client_id: @client_version.to_s,
          server_id: @config.server_id.to_s,
          client_kexinit: @client_kexinit_payload,
          server_kexinit: @server_kexinit_payload,
          server_host_key: host_key.public_key_blob,
          client_public: client_public,
          server_public: server_public,
          shared_secret: kex_algorithm.shared_secret,
        )

        exchange_hash = kex_algorithm.compute_exchange_hash(exchange)
        signature = host_key.sign(exchange_hash)

        kex_ecdh_reply = Protocol::KexEcdhReply.new(
          algorithm: @algorithms.host_key,
          public_host_key: host_key.public_key_blob,
          public_key: server_public,
          signature:,
        )

        @packet_stream.write(kex_ecdh_reply.serialize)
        puts "[crussh] KEX_ECDH_REPLY sent"

        newkeys = Protocol::NewKeys.new
        @packet_stream.write(newkeys.serialize)
        puts "[crussh] NEWKEYS sent"

        packet = @packet_stream.read
        Protocol::NewKeys.parse(packet)
        puts "[crussh] NEWKEYS received"

        @session_id ||= exchange_hash

        cipher = Cipher.from_name(@algorithms.cipher_server_to_client)

        keys = kex_algorithm.derive_keys(
          session_id: @session_id,
          exchange_hash:,
          cipher:,
          mac_c2s: nil,
          mac_s2c: nil,
          we_are_server: true,
        )

        puts "[crussh] Keys derived:"
        puts "[crussh]   key_send: #{keys[:key_send].bytesize} bytes"
        puts "[crussh]   key_recv: #{keys[:key_recv].bytesize} bytes"

        opening_key = cipher.make_opening_key(key: keys[:key_recv])
        sealing_key = cipher.make_sealing_key(key: keys[:key_send])

        @packet_stream.enable_encryption(opening_key, sealing_key)
        puts "[crussh] Encryption enabled"
      end

      def service_request
        packet = @packet_stream.read
        request = Protocol::ServiceRequest.parse(packet)

        puts "[crussh] Service request: #{request.service_name}"

        unless request.service_name == "ssh-userauth"
          raise ProtocolError, "Unknown service: #{request.service_name}"
        end

        accept = Protocol::ServiceAccept.new(service_name: "ssh-userauth")
        @packet_stream.write(accept.serialize)
      end
    end
  end
end
