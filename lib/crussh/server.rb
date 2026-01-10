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
        auth_handlers[method] = AuthHandler.new(block)
      end

      def auth_handlers
        @auth_handlers ||= {}
      end

      def accept(*types, only: nil, except: nil, if: nil, unless: nil, &block)
        rule = RequestRule.accept(
          only: only,
          except: except,
          if: binding.local_variable_get(:if),
          unless: binding.local_variable_get(:unless),
          &block
        )

        types.each { |type| request_rules[type] = rule }
      end

      def reject(*types)
        rule = RequestRule.reject

        types.each { |type| request_rules[type] = rule }
      end

      def request_rules
        @request_rules ||= {}
      end

      def handle(type, handler = nil, &block)
        handlers[type] = handler || block
      end

      def handlers
        @handlers ||= {}
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

      @gatekeeper = Gatekeeper.new(
        max_connections: @config.max_connections,
        max_unauthenticated: @config.max_unauthenticated,
      )
    end

    attr_reader :config, :gatekeeper

    def run
      Logger.info(self, "Starting server", host: config.host, port: config.port)

      endpoint = IO::Endpoint.tcp(config.host, config.port)

      Async do |task|
        endpoint.bind do |server|
          loop do
            socket, address = server.accept

            task.async do
              handle_connection(socket, address)
            end
          end
        end
      end
    end

    def handle_auth(method, *args)
      handler = self.class.auth_handlers[method]
      return Auth.reject unless handler

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
        has_handler?(:shell) || has_handler?(:exec) || has_handler?(:subsystem)
      when :direct_tcpip
        has_handler?(:direct_tcpip)
      when :forwarded_tcpip
        has_handler?(:forwarded_tcpip)
      when :x11
        has_handler?(:x11)
      else
        false
      end
    end

    def open_channel?(type, channel, ...)
      method_name = :"open_#{type}?"

      return true unless respond_to?(method_name)

      send(method_name, channel, ...)
    end

    def accepts_request?(type, channel, **params)
      rule = self.class.request_rules[type]

      return type == :pty if rule.nil?

      rule.allowed?(channel, **params)
    end

    def dispatch_handler(type, channel, session, *args)
      handler_class_or_proc = self.class.handlers[type]
      return false unless handler_class_or_proc

      case handler_class_or_proc
      when Class
        handler = handler_class_or_proc.new(channel, session, *args)
        handler.call
      when Proc, Method
        handler_class_or_proc.call(channel, session, *args)
      end

      true
    end

    def has_handler?(type)
      self.class.handlers.key?(type)
    end

    private

    def handle_connection(socket, address)
      peer = format_address(address)

      Logger.info(self, "New connection", peer:)

      if @gatekeeper.block?
        Logger.warn(self, "Connection rejected, limit reached", peer: peer, **@gatekeeper.stats)
        socket.close
        return
      end

      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if config.nodelay?

      session = Session.new(socket, server: self)
      session.start

      Logger.info(self, "connection closed", peer:)
    rescue => e
      Logger.error(self, "Connection error", error: e.message)
    ensure
      @gatekeeper.disconnect!(was_authenticated: !session&.user.nil?)
      begin
        socket.close unless socket.closed?
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
