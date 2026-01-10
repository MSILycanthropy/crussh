# frozen_string_literal: true

module Crussh
  module Protocol
    class Pong < Message
      message_type PONG

      field :data, :string, default: ""
    end
  end
end
