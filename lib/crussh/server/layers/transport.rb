# frozen_string_literal: true

module Crussh
  class Server
    module Layers
      class Transport
        def initialize(session)
          @session = session
          @client_version = nil
          @algorithms = nil
          @session_id = nil
          @client_kexinit_payload = nil
          @server_kexinit_payload = nil
        end

        attr_reader :client_version, :algorithms, :session_id

        def run
          version_exchange
          algorithm_negotiation
          key_exchange
        end

        private

        def config = @session.config
        def socket = @session.socket
        def packet_stream = @session.packet_stream

        def host_key
          @host_key ||= config.host_keys.find { |key| key.algorithm == @algorithms.host_key }
        end

        def version_exchange
          exchange = ::Crussh::Transport::VersionExchange.new(socket, server_id: config.server_id)

          @client_version = exchange.exchange

          Logger.info(
            self,
            "Version exchange complete",
            client_version: @client_version.software_version,
            comments: @client_version.comments,
          )
        end

        def algorithm_negotiation
          @client_kexinit_payload = packet_stream.read

          client_kexinit = Protocol::KexInit.parse(@client_kexinit_payload)

          Logger.debug(
            self,
            "Client KEXINIT received",
            kex: client_kexinit.kex_algorithms,
            host_key: client_kexinit.server_host_key_algorithms,
            cipher_c2s: client_kexinit.cipher_client_to_server.first(3),
            cipher_s2c: client_kexinit.cipher_server_to_client.first(3),
          )

          server_kexinit = Protocol::KexInit.from_preferred(config.preferred)
          @server_kexinit_payload = server_kexinit.serialize
          packet_stream.write(@server_kexinit_payload)

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
          packet = packet_stream.read
          kex_dh_init = Protocol::KexEcdhInit.parse(packet)
          client_public = kex_dh_init.public_key

          Logger.debug(self, "KEX_ECDH_INIT received", public_key_size: client_public.bytesize)

          kex_algorithm = Kex.from_name(@algorithms.kex)
          server_public = kex_algorithm.server_dh_reply(client_public)

          Logger.debug(self, "Key exchange computed", server_public_size: server_public.bytesize)

          exchange = Kex::Exchange.new(
            client_id: @client_version.to_s,
            server_id: config.server_id.to_s,
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
            signature: signature,
          )

          packet_stream.write(kex_ecdh_reply.serialize)
          Logger.debug(self, "KEX_ECDH_REPLY sent")

          newkeys = Protocol::NewKeys.new
          packet_stream.write(newkeys.serialize)
          Logger.debug(self, "NEWKEYS sent")

          packet = packet_stream.read
          Protocol::NewKeys.parse(packet)
          Logger.debug(self, "NEWKEYS received")

          @session_id = exchange_hash

          cipher = Cipher.from_name(@algorithms.cipher_server_to_client)

          keys = kex_algorithm.derive_keys(
            session_id: @session_id,
            exchange_hash: exchange_hash,
            cipher: cipher,
            mac_c2s: nil,
            mac_s2c: nil,
            we_are_server: true,
          )

          Logger.debug(
            self,
            "Keys derived",
            key_send_size: keys[:key_send].bytesize,
            key_recv_size: keys[:key_recv].bytesize,
          )

          opening_key = cipher.make_opening_key(key: keys[:key_recv])
          sealing_key = cipher.make_sealing_key(key: keys[:key_send])

          packet_stream.enable_encryption(opening_key, sealing_key)
          Logger.info(self, "Encryption enabled", cipher: @algorithms.cipher_server_to_client)
        end
      end
    end
  end
end
