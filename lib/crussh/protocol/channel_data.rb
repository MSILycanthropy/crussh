# frozen_string_literal: true

module Crussh
  module Protocol
    class ChannelData < Message
      message_type CHANNEL_DATA

      field :recipient_channel, :uint32
      field :data, :string
    end
  end
end
