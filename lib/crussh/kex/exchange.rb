# frozen_string_literal: true

module Crussh
  module Kex
    class Exchange
      def initialize(session)
        @session = session
        @session_id = session.id
      end

      attr_reader :algorithms, :session_id

      def config = @session.config

      def initial(client_version:)
        @client_version = client_version
        @client_kexinit_payload = @session.read_raw_packet

        perform_full_key_exchange
      end

      def start_rekey
        server_kexinit = Protocol::KexInit.from_preferred(config.preferred)
        @server_kexinit_payload = server_kexinit.serialize
        @session.write_raw_packet(server_kexinit)

        @client_kexinit_payload = @session.read_packet_raw
        client_kexinit = Protocol::KexInit.parse(@client_kexinit_payload)

        negotiate_and_exchange(client_kexinit, server_kexinit)
      end

      def rekey(client_kexinit_payload:)
        @client_kexinit_payload = client_kexinit_payload

        perform_full_key_exchange
      end

      private

      def perform_full_key_exchange
        client_kexinit = Protocol::KexInit.parse(@client_kexinit_payload)

        server_kexinit = Protocol::KexInit.from_preferred(config.preferred)
        @server_kexinit_payload = server_kexinit.serialize
        @session.write_raw_packet(server_kexinit)

        negotiate_and_exchange(client_kexinit, server_kexinit)
      end

      def negotiate_and_exchange(client_kexinit, server_kexinit)
        @algorithms = Negotiator.new(client_kexinit, server_kexinit).negotiate

        perform_dh_exchange
        derive_and_enable_keys
      end

      def perform_dh_exchange
        packet = @session.read_raw_packet
        kex_dh_init = Protocol::KexEcdhInit.parse(packet)
        client_public = kex_dh_init.public_key

        @kex_algorithm = Kex.from_name(@algorithms.kex)
        server_public = @kex_algorithm.server_dh_reply(client_public)

        parameters = Parameters.new(
          client_id: @client_version.to_s,
          server_id: config.server_id.to_s,
          client_kexinit: @client_kexinit_payload,
          server_kexinit: @server_kexinit_payload,
          server_host_key: host_key.public_key_blob,
          client_public: client_public,
          server_public: server_public,
          shared_secret: kex_algorithm.shared_secret,
        )

        exchange_hash = kex_algorithm.compute_exchange_hash(parameters)
        signature = host_key.sign(exchange_hash)

        kex_ecdh_reply = Protocol::KexEcdhReply.new(
          algorithm: @algorithms.host_key,
          public_host_key: host_key.public_key_blob,
          public_key: server_public,
          signature: signature,
        )

        @session.write_raw_packet(kex_ecdh_reply)
        @session.write_raw_packet(Protocol::NewKeys.new)

        packet = @session.read_packet
        Protocol::NewKeys.parse(packet)

        @session_id ||= @exchange_hash
      end

      def derive_and_enable_keys
        cipher = Cipher.from_name(@algorithms.cipher_server_to_client)

        keys = kex_algorithm.derive_keys(
          session_id: @session_id,
          exchange_hash: exchange_hash,
          cipher: cipher,
          mac_c2s: nil,
          mac_s2c: nil,
          we_are_server: true,
        )

        opening_key = cipher.make_opening_key(key: keys[:key_recv])
        sealing_key = cipher.make_sealing_key(key: keys[:key_send])

        @session.enable_encryption(opening_key, sealing_key)

        Logger.info(self, "Keys exchanged", cipher: @algorithms.cipher_server_to_client)
      end

      def host_key
        @host_key ||= config.host_keys.find { |key| key.algorithm == @algorithms.host_key }
      end
    end
  end
end
