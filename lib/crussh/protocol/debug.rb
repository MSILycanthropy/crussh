# frozen_string_literal: true

module Crussh
  module Protocol
    class Debug < Message
      message_type DEBUG

      field :always_display, :boolean
      field :message, :string
      field :language, :string, default: ""

      def always_display? = @always_display
    end
  end
end
