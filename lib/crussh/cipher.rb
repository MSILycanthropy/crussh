# frozen_string_literal: true

module Crussh
  module Cipher
    CHACHA20_POLY1305 = "chacha20-poly1305@openssh.com"

    DEFAULT = [CHACHA20_POLY1305]

    ALL = [CHACHA20_POLY1305]

    REGISTRY = {
      CHACHA20_POLY1305 => ChaCha20Poly1305,
    }

    class << self
      def from_name(name)
        algorithm_class = REGISTRY[name]

        raise UnknownAlgorithm, "Unknown cipher algorithm: #{name}" if algorithm_class.nil?

        algorithm_class.new
      end
    end

    class Base
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
