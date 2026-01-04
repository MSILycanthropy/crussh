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
      # @config.validate!

      puts "[crussh] Starting server on #{@host}:#{@port}"
      puts "[crussh] Server ID: #{@config.server_id}"

      Async do
        @endpoint.accept(&method(:accept))
      end
    end

    private

    def accept(socket, address, _task: Async::Task.current)
      peer = format_address(address)
      puts "[crussh] New connection from #{peer}"

      handler = @handler_class.new
      session = Session.new(socket, config: @config, handler: handler)
      session.start

      puts "[crussh] Session from #{peer} closed"
    rescue StandardError => e
      puts "[crussh] Error handling #{peer}: #{e.message}"
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
