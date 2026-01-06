# frozen_string_literal: true

module Crussh
  module Cipher
    class Algorithm
      def key_length
        raise NotImplementedError
      end

      def nonce_length
        0
      end

      def block_size
        8
      end

      def needs_mac?
        true
      end

      def make_opening_key(key:, nonce:, mac_key:, mac:)
        raise NotImplementedError
      end

      def make_sealing_key(key:, nonce:, mac_key:, mac:)
        raise NotImplementedError
      end
    end
  end
end
