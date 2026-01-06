# frozen_string_literal: true

module Crussh
  module Protocol
    class KexEcdhInit < Packet
      message_type KEX_ECDH_INIT

      field :public_key, :string
    end
  end
end
