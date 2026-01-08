# frozen_string_literal: true

module Crussh
  module Protocol
    class Unimplemented < Message
      message_type UNIMPLEMENTED

      field :sequence_number, :uint32
    end
  end
end
