# frozen_string_literal: true

module Crussh
  module Protocol
    class Ping < Message
      message_type PING

      field :data, :string, default: ""
    end
  end
end
