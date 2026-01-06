# frozen_string_literal: true

module Crussh
  module Protocol
    class KexInit < Packet
      message_type KEXINIT

      field :cookie, :raw, length: 16, default: -> { SecureRandom.random_bytes(16) }
      field :kex_algorithms, :name_list, default: []
      field :server_host_key_algorithms, :name_list, default: []
      field :cipher_client_to_server, :name_list, default: []
      field :cipher_server_to_client, :name_list, default: []
      field :mac_client_to_server, :name_list, default: []
      field :mac_server_to_client, :name_list, default: []
      field :compression_client_to_server, :name_list, default: []
      field :compression_server_to_client, :name_list, default: []
      field :languages_client_to_server, :name_list, default: []
      field :languages_server_to_client, :name_list, default: []
      field :first_kex_packet_follows, :boolean, default: false
      field :reserved, :uint32, default: 0

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
      end
    end
  end
end
