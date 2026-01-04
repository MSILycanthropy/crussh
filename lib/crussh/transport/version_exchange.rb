# frozen_string_literal: true

module Crussh
  module Transport
    class VersionExchange
      MAX_VERSION_LENGTH = 255

      def initialize(socket, server_id:)
        @socket = socket
        @server_id = server_id
      end

      def exchange
        @socket.write(@server_id.serialize)

        loop do
          line = @socket.readline(MAX_VERSION_LENGTH, chomp: true)

          next unless line.start_with?("SSH-")

          return SshId.parse(line)
        end
      end
    end
  end
end
