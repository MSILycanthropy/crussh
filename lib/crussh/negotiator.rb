# frozen_string_literal: true

module Crussh
  class Negotiator
    SUPPORTED_ALGS = {
      kex_algorithms: [
        "curve25519-sha256",
        "curve25519-sha256@libssh.org",
      ],
      server_host_key_algorithms: [
        "ssh-ed25519",
      ],
      encryption_algorithms_client_to_server: [
        "chacha20-poly1305@openssh.com",
      ],
      encryption_algorithms_server_to_client: [
        "chacha20-poly1305@openssh.com",
      ],
      mac_algorithms_client_to_server: [
        "none",
      ],
      mac_algorithms_server_to_client: [
        "none",
      ],
      compression_algorithms_client_to_server: [
        "none",
      ],
      compression_algorithms_server_to_client: [
        "none",
      ],
      languages_client_to_server: [],
      languages_server_to_client: [],
    }.freeze

    Algorithms = Struct.new(
      :kex,
      :host_key,
      :cipher_client_to_server,
      :cipher_server_to_client,
      :mac_client_to_server,
      :mac_server_to_client,
      :compression_client_to_server,
      :compression_server_to_client,
      keyword_init: true,
    )

    def initialize(client_kexinit, server_kexinit)
      @client_kexinit = client_kexinit
      @server_kexinit = server_kexinit
    end

    def negotiate
      Algorithms.new(
        kex: pick!(:kex_algorithms),
        host_key: pick!(:server_host_key_algorithms),
        cipher_client_to_server: pick!(:encryption_client_to_server),
        cipher_server_to_client: pick!(:encryption_server_to_client),
        mac_client_to_server: pick(:mac_client_to_server),
        mac_server_to_client: pick(:mac_server_to_client),
        compression_client_to_server: pick!(:compression_client_to_server),
        compression_server_to_client: pick!(:compression_server_to_client),
      )
    end

    private

    def pick!(category)
      pick(category) || raise(NegotationError, "No supported common algorithm for #{category}")
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
