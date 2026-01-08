# frozen_string_literal: true

module Crussh
  class Server
    class << self
      def configure
        yield config
      end

      def config
        @config ||= Config.new
      end

      def banner(text = nil, &block)
        return @banner = block if block

        @banner = text
      end

      def read_banner
        @banner.is_a?(Proc) ? @banner.call : @banner
      end

      def authenticate(method, &block)
        auth_handlers[method] = block
      end

      def auth_handlers
        @auth_handlers ||= {}
      end

      def inherited(subclass)
        subclass.instance_variable_set(:@config, config.dup)
        subclass.instance_variable_set(:@auth_handlers, auth_handlers.dup)
        subclass.instance_variable_set(:@banner, @banner)

        super
      end

      def run(**options)
        new(**options).run
      end
    end

    def initialize(**config)
      @config = self.class.config.dup

      config.each do |key, value|
        @config.public_send(:"#{key}=", value)
      end

      @config.validate!
    end

    attr_reader :config

    def run
      Logger.info(self, "Starting server", host: config.host, port: config.port)

      endpoint = IO::Endpoint.tcp(config.host, config.port)

      Async do |task|
        endpoint.bind do |server|
          loop do
            socket, address = server.accept

            task.with_timeout(config.connection_timeout) do
              handle_connection(socket, address)
            end
          end
        end
      end
    end

    def handle_auth(method, *args)
      handler = self.class.auth_handlers[method]
      return false if handler.nil?

      handler.call(*args)
    end

    def auth_methods
      self.class.auth_handlers.keys
    end

    def banner
      self.class.read_banner
    end

    def accepts_channel?(type)
      case type
      when :session
        respond_to?(:shell) || respond_to?(:exec) || respond_to?(:subsystem)
      when :direct_tcpip
        respond_to?(:direct_tcpip)
      when :forwarded_tcpip
        respond_to?(:forwarded_tcpip)
      when :x11
        respond_to?(:x11)
      else
        false
      end
    end

    def open_channel?(type, channel, ...)
      method_name = :"open_#{type}?"

      return true unless respond_to?(method_name)

      send(method_name, channel, ...)
    end

    def accepts_request?(type, channel, ...)
      method_name = :"accept_#{type}_request?"

      return type == :pty unless respond_to?(method_name)

      send(method_name, channel, ...)
    end

    def handle_channel(type, channel, ...)
      send(type, channel, ...)
    end

    private

    def handle_connection(socket, address)
      peer = format_address(address)

      Logger.info(self, "New connection", peer:)

      session = Session.new(socket, server: self)
      session.start

      Logger.info(self, "connection closed", peer:)
    rescue => e
      Logger.error(self, "Connection error", error: e.message)
    ensure
      begin
        socket.close
      rescue
        nil
      end
    end

    def format_address(address)
      case address
      when Addrinfo
        "#{address.ip_address}:#{address.ip_port}"
      else
        address.to_s
      end
    end
  end
end
