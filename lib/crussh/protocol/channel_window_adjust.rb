# frozen_string_literal: true

module Crussh
  module Protocol
    class ChannelWindowAdjust < Message
      message_type CHANNEL_WINDOW_ADJUST

      field :recipient_channel, :uint32
      field :bytes_to_add, :uint32
    end
  end
end
