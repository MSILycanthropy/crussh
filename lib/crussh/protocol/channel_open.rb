# frozen_string_literal: true

module Crussh
  module Protocol
    class ChannelOpen < Message
      message_type CHANNEL_OPEN

      field :channel_type, :string
      field :sender_channel, :uint32
      field :initial_window_size, :uint32
      field :maximum_packet_size, :uint32
      field :channel_data, :remaining

      def x11?
        channel_type == "x11"
      end

      def forwarded_tcpip?
        channel_type == "forwarded-tcpip"
      end

      def direct_tcpip?
        channel_type == "direct-tcpip"
      end

      def x11
        return @x11 if @x11
        return unless x11?

        reader = Transport::Reader.new(channel_data)

        originator_address = reader.string
        originator_port = reader.uint32

        @x11 = X11.new(originator_address:, originator_port:)
      end
      X11 = Data.define(:originator_address, :originator_port)

      def forwarded_tcpip
        return @forwarded_tcpip if @forwarded_tcpip
        return unless forwarded_tcpip?

        reader = Transport::Reader.new(channel_data)

        address = reader.string
        port = reader.uint32
        originator_address = reader.string
        originator_port = reader.uint32

        @forwarded_tcpip = Tcpip.new(address:, port:, originator_address:, originator_port:)
      end
      Tcpip = Data.define(:address, :port, :originator_address, :originator_port)

      def direct_tcpip
        return @direct_tcpip if @direct_tcpip
        return unless direct_tcpip?

        reader = Transport::Reader.new(channel_data)

        address = reader.string
        port = reader.uint32
        originator_address = reader.string
        originator_port = reader.uint32

        @direct_tcpip = Tcpip.new(address:, port:, originator_address:, originator_port:)
      end
    end
  end
end
