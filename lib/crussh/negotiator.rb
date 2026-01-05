# frozen_string_literal: true

module Crussh
  class Negotiator
    def initialize(client_kexinit, server_kexinit)
      @client_kexinit = client_kexinit
      @server_kexinit = server_kexinit
    end

    def negotiate
      Algorithms.new(
        kex: pick!(:kex_algorithms),
        host_key: pick!(:server_host_key_algorithms),
        cipher_client_to_server: pick!(:cipher_client_to_server),
        cipher_server_to_client: pick!(:cipher_server_to_client),
        mac_client_to_server: pick(:mac_client_to_server),
        mac_server_to_client: pick(:mac_server_to_client),
        compression_client_to_server: pick!(:compression_client_to_server),
        compression_server_to_client: pick!(:compression_server_to_client),
      )
    end

    private

    def pick!(category)
      pick(category) || raise(NegotiationError, "No supported common algorithm for #{category}")
    end

    def pick(category)
      server_list, client_list = extract_lists(category)

      return if client_list.empty? || server_list.empty?

      client_list.find { |algorithm| server_list.include?(algorithm) }
    end

    def extract_lists(category)
      [@server_kexinit.send(category), @client_kexinit.send(category)]
    end
  end
end
