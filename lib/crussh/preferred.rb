# frozen_string_literal: true

module Crussh
  # Algorithm preferences - ordered by preference (first = most preferred)
  class Preferred
    DEFAULT_HOST_KEY_ALGS = [
      "ssh-ed25519",
    ].freeze
    DEFAULT_COMPRESSION_ALGS = ["none"].freeze

    def initialize
      @kex = Kex::DEFAULT
      @host_key = DEFAULT_HOST_KEY_ALGS
      @cipher = Cipher::DEFAULT
      @mac = Mac::DEFAULT
      @compression = DEFAULT_COMPRESSION_ALGS
    end

    attr_accessor :kex, :host_key, :cipher, :mac, :compression
  end
end
