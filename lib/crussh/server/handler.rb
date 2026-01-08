# frozen_string_literal: true

module Crussh
  class Server
    class Handler
      def auth_none(username)
        false
      end

      def auth_password(username, password)
        false
      end

      def auth_publickey_query(username, algorithm, key_blob)
        false
      end

      def auth_publickey(username, algorithm, key_blob, signature, signed_data)
        return false unless auth_publickey_query(username, algorithm, key_blob)

        verify_signature(algorithm, key_blob, signature, signed_data)
      end

      def auth_succeeded(username)
      end

      def auth_banner
      end

      private

      def verify_signature(algorithm, key_blob, signature, signed_data)
        public_key = Keys.parse_public_blob(key_blob)
        public_key.verify(signed_data, signature)
      rescue KeyError, SignatureError => e
        Logger.warn(self, "Signature verification failed", error: e.message)
        false
      end
    end
  end
end
