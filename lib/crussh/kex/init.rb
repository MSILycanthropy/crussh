# frozen_string_literal: true

module Crussh
  module Kex
    class Init
      ALGORITHM_FIELDS = [
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

      def initialize(cookie: nil, first_kex_packet_follows: false, **algorithms)
        @cookie = cookie || SecureRandom.random_bytes(16)
        @algorithms = algorithms
        @first_kex_packet_follows = first_kex_packet_follows
      end

      class << self
        def from_preferred(preferred)
          new(
            kex_algorithms: preferred.kex,
            server_host_key_algorithms: preferred.host_key,
            cipher_client_to_server: preferred.cipher,
            cipher_server_to_client: preferred.cipher,
            mac_client_to_server: preferred.mac,
            mac_server_to_client: preferred.mac,
            compression_client_to_server: preferred.compression,
            compression_server_to_client: preferred.compression,
          )
        end

        def parse(data)
          reader = Transport::Reader.new(data)

          message_type = reader.byte

          raise ProtocolError, "Expected KEXINIT, got #{message_type}" unless message_type == Protocol::SSH_MSG_KEXINIT

          cookie = reader.read(16)

          algorithms = read_algorithms(reader)

          first_kex_packet_follows = reader.boolean

          reader.uint32

          new(cookie:, first_kex_packet_follows:, **algorithms)
        end

        private

        def read_algorithms(reader)
          {
            kex_algorithms: reader.name_list,
            server_host_key_algorithms: reader.name_list,
            cipher_client_to_server: reader.name_list,
            cipher_server_to_client: reader.name_list,
            mac_client_to_server: reader.name_list,
            mac_server_to_client: reader.name_list,
            compression_client_to_server: reader.name_list,
            compression_server_to_client: reader.name_list,
            languages_client_to_server: reader.name_list,
            languages_server_to_client: reader.name_list,
          }
        end
      end

      attr_reader :cookie, :first_kex_packet_follows

      def serialize
        writer = Transport::Writer.new

        writer.byte(Protocol::SSH_MSG_KEXINIT)
        writer.raw(@cookie)
        write_name_lists(writer)
        writer.boolean(@first_kex_packet_follows)
        writer.uint32(0)

        writer.to_s
      end

      Protocol::ALGORITHM_CATEGORIES.each do |category|
        define_method(category) do
          @algorithms[category] || []
        end
      end

      private

      def default_algorithms
        Protocol::ALGORITHM_CATEGORIES.to_h { |category| [category, []] }
      end

      def write_name_lists(writer)
        writer.name_list(kex_algorithms)
        writer.name_list(server_host_key_algorithms)
        writer.name_list(cipher_client_to_server)
        writer.name_list(cipher_server_to_client)
        writer.name_list(mac_client_to_server)
        writer.name_list(mac_server_to_client)
        writer.name_list(compression_client_to_server)
        writer.name_list(compression_server_to_client)
        writer.name_list(languages_client_to_server)
        writer.name_list(languages_server_to_client)
      end
    end
  end
end
