# frozen_string_literal: true

module Crussh
  module Keys
    class KeyPair
      def initialize(private_key, signature_algorithm: nil)
        @private_key = private_key
        @signature_algorithm = signature_algorithm || default_signature_algorithm
      end

      attr_reader :signature_algorithm

      def algorithm
        @private_key.public_key.algo
      end

      def public_key_blob
        @private_key.public_key.rfc4253
      end

      def sign(data)
        @private_key.sign(data, algo: @signature_algorithm)
      end

      def verify(data, signature)
        @private_key.public_key.verify(data, signature)
      end

      def public_key
        @public_key ||= PublicKey.new(@private_key.public_key)
      end

      def fingerprint
        public_key.fingerprint
      end

      def to_authorized_key(comment: nil)
        public_key.to_authorized_key(comment:)
      end

      def to_openssh(passphrase: nil, comment: "")
        @private_key.openssh(comment: comment)
      end

      private

      def default_signature_algorithm
        case @private_key
        when SSHData::PrivateKey::ED25519
          ED25519
        when SSHData::PrivateKey::RSA
          RSA_SHA512
        when SSHData::PrivateKey::ECDSA
          @private_key.public_key.algo
        else
          @private_key.public_key.algo
        end
      end
    end
  end
end
