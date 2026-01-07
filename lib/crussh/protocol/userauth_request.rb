# frozen_string_literal: true

module Crussh
  module Protocol
    class UserauthRequest < Packet
      message_type USERAUTH_REQUEST

      field :username, :string
      field :service_name, :string
      field :method_name, :string
      field :method_data, :remaining
    end
  end
end
