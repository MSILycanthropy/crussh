# frozen_string_literal: true

module Crussh
  module Protocol
    class UserauthRequest < Message
      message_type USERAUTH_REQUEST

      field :username, :string
      field :service_name, :string
      field :method_name, :string
      field :method_data, :remaining

      def none?
        method_name == "none"
      end

      def password?
        method_name == "password"
      end

      def publickey?
        method_name == "publickey"
      end

      def password
        return unless password?
        return @password if @password

        reader = Transport::Reader.new(method_data)
        reader.boolean
        @password = reader.string
      end

      def public_key_data
        return @public_key_data if @public_key_data
        return unless publickey?

        reader = Transport::Reader.new(method_data)
        has_signature = reader.boolean
        algorithm = reader.string
        key_blob = reader.string
        signature = has_signature && !reader.eof? ? reader.string : nil

        @public_key_data = PublicKeyData.new(has_signature, algorithm, key_blob, signature)
      end

      PublicKeyData = Data.define(:has_signature, :algorithm, :key_blob, :signature) do
        def has_signature? = has_signature
      end
    end
  end
end
