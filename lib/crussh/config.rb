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
    attr_accessor :kex, :host_key, :cipher, :mac, :compression

    DEFAULT_KEX_ALGS = [
      "curve25519-sha256",
      "curve25519-sha256@libssh.org",
    ].freeze
    DEFAULT_HOST_KEY_ALGS = [
      "ssh-ed25519",
    ].freeze
    DEFAULT_CIPHER_ALGS = [
      "chacha20-poly1305@openssh.com",
    ].freeze
    DEFAULT_MAC_ALGS = [].freeze
    DEFAULT_COMPRESSION_ALGS = ["none"].freeze

    def initialize
      @kex = DEFAULT_KEX_ALGS
      @host_key = DEFAULT_HOST_KEY_ALGS
      @cipher = DEFAULT_CIPHER_ALGS
      @mac = DEFAULT_MAC_ALGS
      @compression = DEFAULT_COMPRESSION_ALGS
    end
  end
end
