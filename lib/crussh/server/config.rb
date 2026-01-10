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
        @nodelay = false
        @server_id = SshId.new("Crussh_#{VERSION}")

        @host_keys = []
        @host_key_files = []
        @preferred = Preferred.new

        @limits = Limits.new
        @max_packet_size = DEFAULT_PACKET_SIZE
        @window_size = DEFAULT_WINDOW_SIZE
        @channel_buffer_size = 10

        @max_auth_attempts = 6
        @auth_rejection_time = 1
        @auth_rejection_time_initial = nil

        @connection_timeout = 10
        @auth_timeout = nil
        @inactivity_timeout = nil

        @keepalive_interval = nil
        @keepalive_max = 3

        @max_connections = nil
        @max_unauthenticated = nil
      end

      attr_accessor :host,
        :port,
        :server_id,
        :host_keys,
        :host_key_files,
        :preferred,
        :limits,
        :max_packet_size,
        :window_size,
        :channel_buffer_size,
        :max_auth_attempts,
        :auth_rejection_time,
        :auth_rejection_time_initial,
        :connection_timeout,
        :auth_timeout,
        :inactivity_timeout,
        :keepalive_interval,
        :keepalive_max,
        :max_connections,
        :max_unauthenticated

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

        validate_host!
        validate_packet_size!
        validate_timeouts!
        validate_limits!

        self
      end

      def nodelay? = @nodelay

      private

      def load_host_key_files!
        @host_key_files.each do |path|
          @host_keys << Keys.from_file(path)
        end
      end

      def validate_host!
        raise ConfigError, "No host keys configured" if @host_keys.empty?
        raise ConfigError, "host is required" if @host.nil? || @host.empty?
        raise ConfigError, "port must be between 1 and 65535" unless (1..65535).cover?(@port)
      end

      def validate_packet_size!
        if @max_packet_size < MIN_PACKET_SIZE
          raise ConfigError, "max_packet_size too small (min: #{MIN_PACKET_SIZE})"
        end

        if @max_packet_size > MAX_PACKET_SIZE
          raise ConfigError, "max_packet_size too large (max: #{MAX_PACKET_SIZE})"
        end

        raise ConfigError, "window_size must be positive" if @window_size <= 0
        raise ConfigError, "channel_buffer_size must be positive" if @channel_buffer_size <= 0
      end

      def validate_timeouts!
        if @connection_timeout && @connection_timeout <= 0
          raise ConfigError, "connection_timeout must be positive"
        end

        if @auth_timeout && @auth_timeout <= 0
          raise ConfigError, "auth_timeout must be positive"
        end

        if @inactivity_timeout && @inactivity_timeout <= 0
          raise ConfigError, "inactivity_timeout must be positive"
        end

        if @keepalive_interval && @keepalive_interval <= 0
          raise ConfigError, "keepalive_interval must be positive"
        end

        raise ConfigError, "keepalive_max must be positive" if @keepalive_max <= 0

        if @auth_rejection_time&.negative?
          raise ConfigError, "auth_rejection_time cannot be negative"
        end

        if @auth_rejection_time_initial&.negative?
          raise ConfigError, "auth_rejection_time_initial cannot be negative"
        end
      end

      def validate_limits!
        if @max_connections && @max_connections <= 0
          raise ConfigError, "max_connections must be positive"
        end

        if @max_unauthenticated && @max_unauthenticated <= 0
          raise ConfigError, "max_unauthenticated must be positive"
        end

        raise ConfigError, "max_auth_attempts must be positive" if @max_auth_attempts <= 0
      end
    end
  end
end
