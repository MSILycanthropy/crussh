# frozen_string_literal: true

module Crussh
  module Protocol
    class KexEcdhReply < Message
      message_type KEX_ECDH_REPLY

      field :public_host_key, :string
      field :public_key, :string
      field :signature, :string
    end
  end
end
