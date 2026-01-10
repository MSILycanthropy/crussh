# frozen_string_literal: true

module Crussh
  # Algorithm preferences - ordered by preference (first = most preferred)
  class Preferred
    def initialize
      @kex = Kex::DEFAULT
      @host_key = Keys::DEFAULT
      @cipher = Cipher::DEFAULT
      @mac = Mac::DEFAULT
      @compression = Compression::DEFAULT
    end

    attr_accessor :kex, :host_key, :cipher, :mac, :compression
  end
end
