# frozen_string_literal: true

module Crussh
  module Protocol
    class ChannelOpenConfirmation < Message
      message_type CHANNEL_OPEN_CONFIRMATION

      field :recipient_channel, :uint32
      field :sender_channel, :uint32
      field :initial_window_size, :uint32
      field :maximum_packet_size, :uint32
      field :channel_data, :remaining, default: ""
    end
  end
end
