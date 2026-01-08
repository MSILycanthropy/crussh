# frozen_string_literal: true

module Crussh
  module Protocol
    class RequestSuccess < Message
      message_type REQUEST_SUCCESS

      field :response_data, :remaining
    end
  end
end
