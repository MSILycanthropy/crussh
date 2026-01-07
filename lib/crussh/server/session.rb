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

        Logger.info(self, "Handshake complete")

        service_request
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

      private

      def version_exchange
        exchange = Transport::VersionExchange.new(@socket, server_id: @config.server_id)

        @client_version = exchange.exchange

        Logger.info(
          self,
          "Version exchange complete",
          client_version: @client_version.software_version,
          comments: @client_version.comments,
        )
      end

      def algorithm_negotiation
        @client_kexinit_payload = @packet_stream.read

        client_kexinit = Protocol::KexInit.parse(@client_kexinit_payload)

        Logger.debug(
          self,
          "Client KEXINIT received",
          kex: client_kexinit.kex_algorithms,
          host_key: client_kexinit.server_host_key_algorithms,
          cipher_c2s: client_kexinit.cipher_client_to_server.first(3),
          cipher_s2c: client_kexinit.cipher_server_to_client.first(3),
        )

        server_kexinit = Protocol::KexInit.from_preferred(@config.preferred)
        @server_kexinit_payload = server_kexinit.serialize
        @packet_stream.write(@server_kexinit_payload)

        Logger.debug(self, "Server KEXINIT sent")

        @algorithms = Negotiator.new(client_kexinit, server_kexinit).negotiate

        Logger.info(
          self,
          "Algorithms negotiated",
          kex: @algorithms.kex,
          host_key: @algorithms.host_key,
          cipher_c2s: @algorithms.cipher_client_to_server,
          cipher_s2c: @algorithms.cipher_server_to_client,
          mac_c2s: @algorithms.mac_client_to_server,
          mac_s2c: @algorithms.mac_server_to_client,
          compression_c2s: @algorithms.compression_client_to_server,
          compression_s2c: @algorithms.compression_server_to_client,
        )
      end

      def key_exchange
        packet = @packet_stream.read
        kex_dh_init = Protocol::KexEcdhInit.parse(packet)
        client_public = kex_dh_init.public_key

        Logger.debug(self, "KEX_ECDH_INIT received", public_key: client_public)

        kex_algorithm = Kex.from_name(@algorithms.kex)
        server_public = kex_algorithm.server_dh_reply(client_public)

        Logger.debug(
          self,
          "Key exchange computed",
          public_key: server_public,
        )

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
        Logger.debug(self, "KEX_ECDH_REPLY sent")

        newkeys = Protocol::NewKeys.new
        @packet_stream.write(newkeys.serialize)
        Logger.debug(self, "NEWKEYS sent")

        packet = @packet_stream.read
        Protocol::NewKeys.parse(packet)
        Logger.debug(self, "Client NEWKEYS received")

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
        Logger.debug(
          self,
          "Keys derived",
          key_send_size: keys[:key_send],
          key_recv_size: keys[:key_recv],
        )

        opening_key = cipher.make_opening_key(key: keys[:key_recv])
        sealing_key = cipher.make_sealing_key(key: keys[:key_send])

        @packet_stream.enable_encryption(opening_key, sealing_key)
        Logger.debug(self, "Encryption enabled", cipher: @algorithms.cipher_server_to_client)
      end

      def service_request
        packet = @packet_stream.read
        request = Protocol::ServiceRequest.parse(packet)

        Logger.debug(self, "Service request", service: request.service_name)

        unless request.service_name == "ssh-userauth"
          raise ProtocolError, "Unknown service: #{request.service_name}"
        end

        accept = Protocol::ServiceAccept.new(service_name: "ssh-userauth")
        @packet_stream.write(accept.serialize)

        Logger.debug(self, "Service accepted", service: "ssh-userauth")
      end
    end
  end
end
