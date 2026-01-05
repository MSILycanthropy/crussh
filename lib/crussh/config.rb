# frozen_string_literal: true

module Crussh
  # Thresholds for when to perform key re-exchange.
  # Rekeying is important for long-lived connections to limit
  # the amount of data encrypted under a single key.
  class Limits
    ONE_GB = 1 << 30
    ONE_HOUR = 3600

    attr_accessor :rekey_write_limit,
      :rekey_read_limit,
      :rekey_time_limit

    # defaults from
    # https://datatracker.ietf.org/doc/html/rfc4253#section-9
    def initialize(
      rekey_write_limit: ONE_GB,
      rekey_read_limit: ONE_GB,
      rekey_time_limit: ONE_HOUR
    )
      @rekey_write_limit = rekey_write_limit
      @rekey_read_limit = rekey_read_limit
      @rekey_time_limit = rekey_time_limit
    end
  end

  # Algorithm preferences - ordered by preference (first = most preferred)
  class Preferred
    DEFAULT_HOST_KEY_ALGS = [
      "ssh-ed25519",
    ].freeze
    DEFAULT_COMPRESSION_ALGS = ["none"].freeze

    def initialize
      @kex = Kex::Algorithms::DEFAULT
      @host_key = DEFAULT_HOST_KEY_ALGS
      @cipher = Cipher::Algorithms::DEFAULT
      @mac = Mac::Algorithms::DEFAULT
      @compression = DEFAULT_COMPRESSION_ALGS
    end

    attr_accessor :kex, :host_key, :cipher, :mac, :compression
  end
end
