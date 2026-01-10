# frozen_string_literal: true

module Crussh
  module Protocol
    class GlobalRequest < Message
      message_type GLOBAL_REQUEST

      field :request_type, :string
      field :want_reply, :boolean, default: false
      field :request_data, :remaining, default: ""

      def tcpip_forward?
        request_type == "tcpip-forward"
      end

      def cancel_tcpip_forward?
        request_type == "cancel-tcpip-forward"
      end

      def tcpip_forward
        return @tcpip_forward if @tcpip_forward
        return unless tcpip_forward?

        reader = Transport::Reader.new(request_data)

        address = reader.string
        port = reader.uint32

        @tcpip_forward = TcpipForward.new(address:, port:)
      end
      TcpipForward = Data.define(:address, :port)

      def cancel_tcpip_forward
        return @cancel_tcpip_forward if @cancel_tcpip_forward
        return unless cancel_tcpip_forward?

        reader = Transport::Reader.new(request_data)

        address = reader.string
        port = reader.uint32

        @cancel_tcpip_forward = TcpipForward.new(address:, port:)
      end
    end
  end
end
