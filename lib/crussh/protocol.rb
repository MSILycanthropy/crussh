# frozen_string_literal: true

module Crussh
  module Protocol
    ALGORITHM_CATEGORIES = [
      :kex_algorithms,
      :server_host_key_algorithms,
      :cipher_client_to_server,
      :cipher_server_to_client,
      :mac_client_to_server,
      :mac_server_to_client,
      :compression_client_to_server,
      :compression_server_to_client,
      :languages_client_to_server,
      :languages_server_to_client,
    ].freeze

    # Messages

    DISCONNECT      = 1
    IGNORE          = 2
    UNIMPLEMENTED   = 3
    DEBUG           = 4
    SERVICE_REQUEST = 5
    SERVICE_ACCEPT  = 6

    KEXINIT         = 20
    NEWKEYS         = 21

    # http://tools.ietf.org/html/rfc5656#section-7.1
    KEX_ECDH_INIT      = 30
    KEX_ECDH_REPLY     = 31

    KEX_DH_GEX_REQUEST = 34
    KEX_DH_GEX_GROUP   = 31
    KEX_DH_GEX_INIT    = 32
    KEX_DH_GEX_REPLY   = 33

    class Packet
      class << self
        def message_type(type = nil)
          return @message_type if type.nil?

          @message_type = type
        end

        def field(name, type, **options)
          fields << { name:, type:, **options }

          attr_reader(name)
        end

        def fields
          @fields ||= []
        end

        def parse(data)
          reader = Transport::Reader.new(data)

          wire_message_type = reader.byte

          unless wire_message_type == message_type
            raise ProtocolError, "Expected #{name}, got message type #{wire_message_type}"
          end

          values = {}
          fields.each do |f|
            values[f[:name]] = read_field(reader, f)
          end

          new(**values)
        end

        private

        def read_field(reader, field)
          case field[:type]
          when :raw then reader.read(field[:length])
          else
            reader.send(field[:type])
          end
        end
      end

      def initialize(**values)
        self.class.fields.each do |f|
          value = if values.key?(f[:name])
            values[f[:name]]
          elsif f.key?(:default)
            default = f[:default]
            default.is_a?(Proc) ? default.call : default
          else
            raise ArgumentError, "missing keyword: :#{f[:name]}"
          end

          instance_variable_set(:"@#{f[:name]}", value)
        end
      end

      def serialize
        writer = Transport::Writer.new
        writer.byte(self.class.message_type)

        self.class.fields.each do |field|
          value = instance_variable_get(:"@#{field[:name]}")

          writer.send(field[:type], value)
        end

        writer.to_s
      end
    end
  end
end
