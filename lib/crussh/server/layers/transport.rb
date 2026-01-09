# frozen_string_literal: true

module Crussh
  class Server
    module Layers
      class Transport
        def initialize(session)
          @session = session
          @client_version = nil
          @algorithms = nil
          @session_id = nil
          @client_kexinit_payload = nil
          @server_kexinit_payload = nil
        end

        attr_reader :client_version, :algorithms, :session_id

        def run
          version_exchange
          key_exchange
        end

        private

        def config = @session.config
        def socket = @session.socket

        def version_exchange
          exchange = ::Crussh::Transport::VersionExchange.new(socket, server_id: config.server_id)

          @client_version = exchange.exchange

          Logger.info(
            self,
            "Version exchange complete",
            client_version: @client_version.software_version,
            comments: @client_version.comments,
          )
        end

        def key_exchange
          kex = Kex::Exchange.new(@session)
          kex.initial(client_version: @client_version)
          @session_id = kex.session_id
        end
      end
    end
  end
end
