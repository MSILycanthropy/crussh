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
  end
end
