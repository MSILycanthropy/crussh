# frozen_string_literal: true

module Crussh
  class Server
    DEFAULT_PORT = 22

    def initialize(config, host, port = DEFAULT_PORT, handler_class = Handler)
      @config = config
      @host = host
      @port = port
      @handler_class = handler_class

      tcp_endpoint = IO::Endpoint.tcp(host, port)
      @endpoint = Endpoint.new(tcp_endpoint)
    end

    attr_reader :config, :host, :port

    def run
      @config.validate!

      Logger.info(self, "Starting server", host:, port:)
      Logger.debug(self, "Server configuration", server_id: @config.server_id.to_s)

      Async do
        @endpoint.accept(&method(:accept))
      end
    end

    private

    def accept(socket, address, _task: Async::Task.current)
      peer = format_address(address)
      Logger.info(self, "New connection", peer: peer)

      handler = @handler_class.new
      session = Session.new(socket, config: @config, handler: handler)
      session.start

      Logger.info(self, "Session closed", peer: peer)
    rescue StandardError => e
      Logger.error(self, "Error handling connection", e)
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
