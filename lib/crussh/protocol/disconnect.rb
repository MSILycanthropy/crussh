# frozen_string_literal: true

module Crussh
  module Protocol
    class Disconnect < Message
      message_type DISCONNECT

      field :reason_code, :uint32
      field :description, :string, default: ""
      field :language, :string, default: ""

      REASONS_MAP = {
        host_not_allowed_to_connect: 1,
        protocol_error: 2,
        key_exchange_failed: 3,
        reserved: 4,
        mac_error: 5,
        compression_error: 6,
        service_not_available: 7,
        protocol_version_not_supported: 8,
        host_key_not_verifiable: 9,
        connection_lost: 10,
        by_application: 11,
        too_many_connections: 12,
        auth_cancelled_by_user: 13,
        no_more_auth_methods_available: 14,
        illegal_user_name: 15,
      }

      class << self
        def build(reason, description = "")
          reason_code = REASONS_MAP[reason]

          new(reason_code:, description:)
        end
      end
    end
  end
end
