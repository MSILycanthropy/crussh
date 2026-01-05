# frozen_string_literal: true

module Crussh
  class Server
    class Config
      MIN_PACKET_SIZE = 1024
      MAX_PACKET_SIZE = 256 * 1024
      DEFAULT_PACKET_SIZE = 32_768
      DEFAULT_WINDOW_SIZE = 2 * 1024 * 1024

      def initialize
        @server_id = SshId.new("Crussh_#{VERSION}")
        @limits = Limits.new
        @max_packet_size = DEFAULT_PACKET_SIZE
        @window_size = DEFAULT_WINDOW_SIZE
        @channel_buffer_size = 10
        @host_keys = []
        @preferred = Preferred.new
        @connection_timeout = 10
        @auth_rejection_time = 1
        @inactivity_timeout = nil
      end

      attr_accessor :server_id,
        :limits,
        :max_packet_size,
        :window_size,
        :channel_buffer_size,
        :host_keys,
        :preferred,
        :connection_timeout,
        :auth_rejection_time,
        :inactivity_timeout

      class << self
        # TODO: ensure auto generated host key
        def development
          new
        end

        def customize
          instance = new

          yield instance

          instance
        end
      end

      def validate!
        raise ConfigError, "No host keys configured" if @host_keys.empty?

        validate_packet_size

        raise ConfigError, "window_size must be positive" if @window_size <= 0

        raise ConfigError, "connection_timeout must be positive" if @connection_timeout && @connection_timeout <= 0

        if @auth_rejection_time&.negative?
          raise ConfigError,
            "auth_rejection_time cannot rubbe negative"
        end

        self
      end

      private

      def validate_packet_size
        if @max_packet_size < MIN_PACKET_SIZE
          raise ConfigError,
            "max_packet_size too small (min: #{MIN_PACKET_SIZE})"
        end

        return if @max_packet_size <= MAX_PACKET_SIZE

        raise ConfigError,
          "max_packet_size too large (max: #{MAX_PACKET_SIZE})"
      end
    end
  end
end
