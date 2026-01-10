# frozen_string_literal: true

module Crussh
  module Mac
    class HmacShaAlgorithm < Algorithm
      def initialize(key)
        super

        @key = key
      end

      def compute(sequence, data, writer)
        mac = OpenSSL::HMAC.digest(digest_name, @key, [sequence].pack("N") + data)
        writer.raw(mac)
      end

      def verify?(sequence, data, mac)
        expected = OpenSSL::HMAC.digest(digest_name, @key, [sequence].pack("N") + data)
        OpenSSL.secure_compare(expected, mac)
      end

      private

      def digest_name
        raise NotImplementedError
      end
    end

    class HmacSha1 < HmacShaAlgorithm
      NAME = "hmac-sha1"

      def key_length = 20
      def mac_len = 20
      def digest_name = "SHA1"
    end

    class HmacSha256 < HmacShaAlgorithm
      def key_length = 32
      def mac_length = 32
      def digest_name = "SHA256"
    end

    class HmacSha256Etm < HmacSha256
      def etm? = true
    end

    class HmacSha512 < HmacShaAlgorithm
      NAME = "hmac-sha2-512"

      def key_length = 64
      def mac_length = 64
      def digest_name = "SHA512"
    end

    class HmacSha512Etm < HmacSha512
      NAME = "hmac-sha2-512-etm@openssh.com"

      def etm? = true
    end
  end
end
