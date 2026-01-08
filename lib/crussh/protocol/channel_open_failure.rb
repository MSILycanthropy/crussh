# frozen_string_literal: true

module Crussh
  module Protocol
    class ChannelOpenFailure < Message
      message_type CHANNEL_OPEN_FAILURE

      field :recipient_channel, :uint32
      field :reason_code, :uint32
      field :description, :string
      field :language, :string, default: ""
    end
  end
end
