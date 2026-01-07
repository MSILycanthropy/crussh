# frozen_string_literal: true

module Crussh
  module Logger
    class Filter
      DEFAULT_FILTERED_KEYS = [
        :password,
        :passphrase,
        :private_key,
        :secret,
        :key_blob,
        :signature,
        :shared_secret,
        :session_id,
        :mac_key,
        :encryption_key,
        :iv,
        :nonce,
        :token,
        :credential,
      ].freeze

      FILTERED = "[FILTERED]"
      BINARY_PREVIEW_BYTES = 4

      def initialize(keys: DEFAULT_FILTERED_KEYS)
        @keys = keys.map(&:to_s)
      end

      def apply(value, key: nil)
        return FILTERED if key && filter_key?(key)

        case value
        when Hash
          value.to_h { |k, v| [k, apply(v, key: k)] }
        when Array
          value.map { |v| apply(v) }
        when String
          binary?(value) ? format_binary(value) : value
        else
          value
        end
      end

      private

      def filter_key?(key)
        key_s = key.to_s.downcase
        @keys.any? { |filtered| key_s.include?(filtered) }
      end

      def binary?(value)
        return false if value.empty?

        value.encoding == Encoding::BINARY ||
          !value.valid_encoding? ||
          value.match?(/[^[:print:]\s]/)
      end

      def format_binary(value)
        preview = value.bytes.first(BINARY_PREVIEW_BYTES)
          .map { |b| format("%02x", b) }
          .join
        "<#{value.bytesize} bytes: 0x#{preview}...>"
      end
    end

    class << self
      attr_writer :filter

      def filter
        @filter ||= Filter.new
      end

      def debug(subject, message = nil, **params)
        Console.debug(subject, message, **filter.apply(params))
      end

      def info(subject, message = nil, **params)
        Console.info(subject, message, **filter.apply(params))
      end

      def warn(subject, message = nil, **params)
        Console.warn(subject, message, **filter.apply(params))
      end

      def error(subject, message = nil, **params)
        Console.error(subject, message, **filter.apply(params))
      end

      def fatal(subject, message = nil, **params)
        Console.fatal(subject, message, **filter.apply(params))
      end
    end
  end
end
