# frozen_string_literal: true

module Crussh
  module Protocol
    class Ignore < Message
      message_type IGNORE

      field :data, :string, default: ""
    end
  end
end
