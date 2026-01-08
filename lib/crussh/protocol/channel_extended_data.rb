# frozen_string_literal: true

module Crussh
  module Protocol
    class ChannelExtendedData < Message
      message_type CHANNEL_EXTENDED_DATA

      field :recipient_channel, :uint32
      field :data_type_code, :uint32
      field :data, :string
    end
  end
end
