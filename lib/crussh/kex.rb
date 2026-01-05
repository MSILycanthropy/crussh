# frozen_string_literal: true

module Crussh
  module Kex
    CURVE25519_SHA256 = "curve25519-sha256"
    CURVE25519_SHA256_LIBSSH = "curve25519-sha256@libssh.org"

    DEFAULT = [CURVE25519_SHA256, CURVE25519_SHA256_LIBSSH]

    REGISTRY = {
      CURVE25519_SHA256 => Curve25519,
      CURVE25519_SHA256_LIBSSH => Curve25519,
    }

    class << self
      def from_name(name)
        algorithm_class = REGISTRY[name]

        raise UnknownAlgorithm, "Unknown KEX algorithm: #{name}" if algorithm_class.nil?

        algorithm_class.new
      end
    end

    class Algorithm
      def skip_exchange?
        false
      end

      def digest(data)
        raise NotImplementedError
      end

      def client_dh_init
        generate_keypair

        @public_key
      end

      def server_dh_reply(client_public)
        generate_keypair
        compute_shared_secret(client_public)

        @public_key
      end

      def client_dh_finish(server_public)
        compute_shared_secret(server_public)
      end

      def compute_exchange_hash(exchange)
        writer = Transport::Writer.new

        writer
          .string(exchange.client_id)
          .string(exchange.server_id)
          .string(exchange.client_kexinit)
          .string(exchange.server_kexinit)
          .string(exchange.server_host_key)
          .string(exchange.client_public)
          .string(exchange.server_public)
          .mpint(shared_secret)

        digest(writer.to_s)
      end

      def derive_keys(session_id:, exchange_hash:, cipher:, mac_c2s:, mac_s2c:, we_are_server:)
        # RFC 4253 §7.2 - Key derivation
        # A = IV client->server
        # B = IV server->client
        # C = encryption key client->server
        # D = encryption key server->client
        # E = MAC key client->server
        # F = MAC key server->client

        if we_are_server
          {
            iv_send: derive_key("B", cipher.block_size, session_id, exchange_hash),
            iv_recv: derive_key("A", cipher.block_size, session_id, exchange_hash),
            key_send: derive_key("D", cipher.key_length, session_id, exchange_hash),
            key_recv: derive_key("C", cipher.key_length, session_id, exchange_hash),
            mac_send: derive_key("F", mac_s2c&.key_length || 0, session_id, exchange_hash),
            mac_recv: derive_key("E", mac_c2s&.key_length || 0, session_id, exchange_hash),
          }
        else
          {
            iv_send: derive_key("A", cipher.block_size, session_id, exchange_hash),
            iv_recv: derive_key("B", cipher.block_size, session_id, exchange_hash),
            key_send: derive_key("C", cipher.key_length, session_id, exchange_hash),
            key_recv: derive_key("D", cipher.key_length, session_id, exchange_hash),
            mac_send: derive_key("E", mac_c2s&.key_length || 0, session_id, exchange_hash),
            mac_recv: derive_key("F", mac_s2c&.key_length || 0, session_id, exchange_hash),
          }
        end
      end

      private

      def derive_key(letter, needed_length, session_id, exchange_hash)
        return "".b if needed_length == 0

        writer = Transport::Writer.new
        k_encoded = writer.mpint(shared_secret).to_s

        key = digest(k_encoded + exchange_hash + letter + session_id)

        # Extend key if needed (RFC 4253 §7.2)
        key += digest(k_encoded + exchange_hash + key) while key.bytesize < needed_length

        key[0, needed_length]
      end
    end
  end
end
