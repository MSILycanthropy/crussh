# frozen_string_literal: true

module Crussh
  module Protocol
    class ChannelEof < Message
      message_type CHANNEL_EOF

      field :recipient_channel, :uint32
    end
  end
end
