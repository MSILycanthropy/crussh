# frozen_string_literal: true

module Crussh
  module Protocol
    class UserauthFailure < Packet
      message_type USERAUTH_FAILURE

      field :authentications, :name_list
      field :partial_success, :boolean, default: false
    end
  end
end
