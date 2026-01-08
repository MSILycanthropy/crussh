# frozen_string_literal: true

module Crussh
  module Protocol
    class UserauthBanner < Message
      message_type USERAUTH_BANNER

      field :message, :string
      field :language, :string, default: ""
    end
  end
end
