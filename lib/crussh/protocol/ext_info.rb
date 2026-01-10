# frozen_string_literal: true

module Crussh
  module Protocol
    class ExtInfo
      def initialize(extensions: {})
        @extensions = extensions
      end

      attr_reader :extensions

      def serialize
        writer = Transport::Writer.new
        writer.byte(EXT_INFO)
        writer.uint32(@extensions.size)

        @extensions.each do |name, value|
          writer.string(name)
          writer.string(value)
        end

        writer.to_s
      end

      class << self
        def parse(data)
          reader = Transport::Reader.new(data)
          wire_message_type = reader.byte

          unless wire_message_type == EXT_INFO
            raise ProtocolError, "Expected EXT_INFO, got message type #{wire_message_type}"
          end

          count = reader.uint32
          extensions = {}

          count.times do
            name = reader.string
            value = reader.string
            extensions[name] = value
          end

          new(extensions: extensions)
        end
      end
    end
  end
end
