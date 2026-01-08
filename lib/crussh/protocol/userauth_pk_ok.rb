# frozen_string_literal: true

module Crussh
  module Protocol
    class UserauthPkOk < Packet
      message_type USERAUTH_PK_OK

      field :algorithm, :string
      field :key_blob, :string
    end
  end
end
