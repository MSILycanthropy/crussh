# frozen_string_literal: true

module Crussh
  module Kex
    # TODO: Technically this is just for the server,
    # so maybe we move it to be in the server module scope
    class Exchange
      def initialize(session)
        @session = session
        @session_id = session.id
        @received_messages = Set.new
        @extra_messages_before_kexinit = 0
      end

      attr_reader :algorithms, :session_id

      def config = @session.config
      def strict_kex? = @session.strict_kex?
      def initial? = @session_id.nil?

      def initial(client_version:)
        @client_version = client_version
        @client_kexinit_payload = read_initial_kexinit

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

        validate_strictness!(client_kexinit) if initial?

        server_kexinit = Protocol::KexInit.from_preferred(config.preferred)
        @server_kexinit_payload = server_kexinit.serialize
        @session.write_raw_packet(server_kexinit)

        negotiate_and_exchange(client_kexinit, server_kexinit)
      end

      def validate_strictness!(client_kexinit)
        @session.strict_kex = client_supports_strict?(client_kexinit)

        if strict_kex? && @extra_messages_before_kexinit.positive?
          raise ProtocolError, "Strict KEX: KEXINIT was not the first message"
        end
      end

      def negotiate_and_exchange(client_kexinit, server_kexinit)
        @algorithms = Negotiator.new(client_kexinit, server_kexinit).negotiate

        perform_dh_exchange
        derive_and_enable_keys
      end

      def perform_dh_exchange
        packet = read_kex_packet(Protocol::KEX_ECDH_INIT)
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
          shared_secret: @kex_algorithm.shared_secret,
        )

        @exchange_hash = @kex_algorithm.compute_exchange_hash(parameters)
        signature = host_key.sign(@exchange_hash)

        kex_ecdh_reply = Protocol::KexEcdhReply.new(
          algorithm: @algorithms.host_key,
          public_host_key: host_key.public_key_blob,
          public_key: server_public,
          signature: signature,
        )

        @session.write_raw_packet(kex_ecdh_reply)
        @session.write_raw_packet(Protocol::NewKeys.new)

        packet = read_kex_packet(Protocol::NEWKEYS)
        Protocol::NewKeys.parse(packet)

        @session_id ||= @exchange_hash
      end

      def derive_and_enable_keys
        cipher = Cipher.from_name(@algorithms.cipher_server_to_client)

        keys = @kex_algorithm.derive_keys(
          session_id: @session_id,
          exchange_hash: @exchange_hash,
          cipher: cipher,
          mac_c2s: nil,
          mac_s2c: nil,
          we_are_server: true,
        )

        opening_key = cipher.make_opening_key(key: keys[:key_recv])
        sealing_key = cipher.make_sealing_key(key: keys[:key_send])

        @session.enable_encryption(opening_key, sealing_key)
        @session.reset_sequence if strict_kex?
        @session.algorithms = @algorithms

        Logger.info(self, "Keys exchanged", cipher: @algorithms.cipher_server_to_client)
      end

      def read_kex_packet(expected_type)
        validate_sequence_hasnt_wrapped! if strict_kex? && initial?

        packet = @session.read_raw_packet
        message_type = packet.getbyte(0)

        if strict_kex? && initial?
          unless kex_message?(message_type)
            raise ProtocolError, "Strict KEX: unexpected message type #{message_type} during initial KEX"
          end

          if @received_messages.include?(message_type)
            raise ProtocolError, "Strict KEX: duplicate message type #{message_type}"
          end

          @received_messages.add(message_type)
        else
          while message_type == Protocol::IGNORE || message_type == Protocol::DEBUG
            packet = @session.read_raw_packet
            message_type = packet.getbyte(0)
          end
        end

        unless message_type == expected_type
          raise ProtocolError, "Unexpected message type #{message_type}, expected #{expected_type}"
        end

        packet
      end

      def read_initial_kexinit
        packet = @session.read_raw_packet
        message_type = packet.getbyte(0)

        while message_type == Protocol::IGNORE || message_type == Protocol::DEBUG
          @extra_messages_before_kexinit += 1
          packet = @session.read_raw_packet
          message_type = packet.getbyte(0)
        end

        unless message_type == Protocol::KEXINIT
          raise ProtocolError, "Expected KEXINIT, got message type #{message_type}"
        end

        @received_messages.add(Protocol::KEXINIT)

        packet
      end

      def validate_sequence_hasnt_wrapped!
        return unless @session.sequence_wrapped?

        raise ProtocolError, "Strict KEX: sequence number wrapped during initial KEX"
      end

      def client_supports_strict?(client_kexinit)
        client_kexinit.kex_algorithms.insersect?([STRICT_CLIENT, STRICT_CLIENT_OPENSSH])
      end

      def kex_message?(type)
        case type
        when Protocol::KEXINIT, Protocol::NEWKEYS,
             Protocol::KEX_ECDH_INIT, Protocol::KEX_ECDH_REPLY
          # TODO: Add other KEX message types when implementing those algorithms:
          # - SSH_MSG_KEXDH_INIT (30), SSH_MSG_KEXDH_REPLY (31) for DH
          # - SSH_MSG_KEX_DH_GEX_* for DH group exchange
          true
        else
          false
        end
      end

      def host_key
        @host_key ||= config.host_keys.find { |key| key.algorithm == @algorithms.host_key }
      end
    end
  end
end
