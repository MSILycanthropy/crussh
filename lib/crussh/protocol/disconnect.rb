# frozen_string_literal: true

module Crussh
  module Protocol
    class Disconnect < Message
      message_type DISCONNECT

      field :reason_code, :uint32
      field :description, :string, default: ""
    end
  end
end
