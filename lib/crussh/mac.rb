# frozen_string_literal: true

module Crussh
  module Mac
    HMAC_SHA256 = "hmac-sha2-256"
    HMAC_SHA256_ETM = "hmac-sha2-256-etm@openssh.com"
    HMAC_SHA512     = "hmac-sha2-512"
    HMAC_SHA512_ETM = "hmac-sha2-512-etm@openssh.com"
    NONE            = "none"

    DEFAULT = [
      HMAC_SHA512_ETM,
      HMAC_SHA256_ETM,
      HMAC_SHA512,
      HMAC_SHA256,
      NONE,
    ].freeze

    REGISTRY = {}

    class << self
      def from_name(name, key)
        algorithm_class = REGISTRY[name]

        raise UnknownAlgorithm, "Unknown MAC algorithm: #{name}" if algorithm_class.nil?

        algorithm_class.new(key)
      end
    end

    class Algorithm
      def initialize(key)
        @key = key
      end

      def key_length = 0
      def mac_length = 0
      def etm? = false

      def compute(sequence, data)
        raise NotImplementedError
      end

      def verify?(sequence, data, mac)
        true
      end
    end
  end
end
