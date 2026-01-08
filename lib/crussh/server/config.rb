# frozen_string_literal: true

module Crussh
  class Server
    class Config
      MIN_PACKET_SIZE = 1024
      MAX_PACKET_SIZE = 256 * 1024
      DEFAULT_PACKET_SIZE = 32_768
      DEFAULT_WINDOW_SIZE = 2 * 1024 * 1024

      def initialize
        @host = "127.0.0.1"
        @port = 22

        @server_id = SshId.new("Crussh_#{VERSION}")
        @limits = Limits.new
        @max_packet_size = DEFAULT_PACKET_SIZE
        @window_size = DEFAULT_WINDOW_SIZE
        @channel_buffer_size = 10
        @host_keys = []
        @host_key_files = []
        @preferred = Preferred.new
        @max_auth_attempts = 6
        @connection_timeout = 10
        @auth_timeout = nil
        @auth_rejection_time = 1
        @inactivity_timeout = nil
      end

      attr_accessor :host,
        :port,
        :server_id,
        :limits,
        :max_packet_size,
        :window_size,
        :channel_buffer_size,
        :host_keys,
        :host_key_files,
        :preferred,
        :max_auth_attempts,
        :connection_timeout,
        :auth_timeout,
        :auth_rejection_time,
        :inactivity_timeout

      def generate_host_keys!
        @host_keys << Keys.generate
        self
      end

      def dup
        copy = super
        copy.instance_variable_set(:@limits, @limits.dup)
        copy.instance_variable_set(:@host_keys, @host_keys.dup)
        copy.instance_variable_set(:@host_key_files, @host_key_files.dup)
        copy.instance_variable_set(:@preferred, @preferred.dup)
        copy
      end

      def validate!
        load_host_key_files!

        raise ConfigError, "No host keys configured" if @host_keys.empty?
        raise ConfigError, "host is required" if @host.nil? || @host.empty?
        raise ConfigError, "port must be between 1 and 65535" unless (1..65535).cover?(@port)

        validate_packet_size

        raise ConfigError, "window_size must be positive" if @window_size <= 0
        raise ConfigError, "connection_timeout must be positive" if @connection_timeout && @connection_timeout <= 0
        raise ConfigError, "auth_rejection_time cannot be negative" if @auth_rejection_time&.negative?

        self
      end

      private

      def load_host_key_files!
        @host_key_files.each do |path|
          @host_keys << Keys.from_file(path)
        end
      end

      def validate_packet_size
        if @max_packet_size < MIN_PACKET_SIZE
          raise ConfigError, "max_packet_size too small (min: #{MIN_PACKET_SIZE})"
        end

        return if @max_packet_size <= MAX_PACKET_SIZE

        raise ConfigError, "max_packet_size too large (max: #{MAX_PACKET_SIZE})"
      end
    end
  end
end
