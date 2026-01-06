# frozen_string_literal: true

module Crussh
  module Protocol
    class ServiceRequest < Packet
      message_type SERVICE_REQUEST

      field :service_name, :string
    end
  end
end
