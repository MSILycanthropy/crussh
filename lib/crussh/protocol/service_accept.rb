# frozen_string_literal: true

module Crussh
  module Protocol
    class ServiceAccept < Packet
      message_type SERVICE_ACCEPT

      field :service_name, :string
    end
  end
end
