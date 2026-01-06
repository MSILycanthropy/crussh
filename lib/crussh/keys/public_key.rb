# frozen_string_literal: true

module Crussh
  module Keys
    class PublicKey
      def initialize(public_key)
        @public_key = public_key
      end

      def algorithm
        @public_key.algo
      end

      def encode
        @public_key.rfc4253
      end

      def verify(data, signature)
        @public_key.verify(data, signature)
      rescue SSHData::VerifyError
        false
      end

      def fingerprint
        @public_key.fingerprint
      end

      def to_authorized_key(comment: nil)
        parts = [@public_key.algo, Base64.strict_encode64(@public_key.encode)]
        parts << comment if comment
        parts.join(" ")
      end
    end
  end
end
