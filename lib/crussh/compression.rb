# frozen_string_literal: true

require "zlib"

module Crussh
  module Compression
    NONE = "none"
    ZLIB = "zlib@openssh.com"

    DEFAULT = [ZLIB, NONE].freeze

    class << self
      def from_name(name)
        case name
        when NONE
          None.new
        when ZLIB
          Zlib.new
        else
          raise UnknownAlgorithm, "Unknown compression: #{name}"
        end
      end
    end

    class Compressor
      def deflate(data) = data
      def inflate(data) = data
    end

    class None < Compressor; end

    class Zlib
      def initialize
        @deflator = ::Zlib::Deflate.new
        @inflator = ::Zlib::Inflate.new
      end

      def deflate(data) = @deflator.deflate(data, ::Zlib::SYNC_FLUSH)
      def inflate(data) = @inflator.inflate(data)
    end
  end
end
