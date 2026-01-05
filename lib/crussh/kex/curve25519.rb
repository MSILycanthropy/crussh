# frozen_string_literal: true

module Crussh
  module Kex
    class Curve25519 < Base
      PUBLIC_KEY_SIZE = 32
      PRIVATE_KEY_SIZE = 32

      def digest(data)
        RbNaCl::Hash.sha256(data)
      end

      def generate_keypair
        @private_key = X25519::Scalar.generate
        @public_key = @private_key.public_key.to_bytes
      end

      def compute_shared_secret(their_public_key)
        raise KexError, "Invalid public key size" if their_public_key.bytesize != PUBLIC_KEY_SIZE

        their_key = RbNaCl::PublicKey.new(their_public_key)
        shared = @private_key.diffie_hellman(their_key)

        @shared_secret = shared.to_bytes.unpack("H*").to_i(16)
      end
    end
  end
end
