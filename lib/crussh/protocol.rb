# frozen_string_literal: true

module Crussh
  module Protocol
    ALGORITHM_CATEGORIES = [
      :kex_algorithms,
      :server_host_key_algorithms,
      :encryption_client_to_server,
      :encryption_server_to_client,
      :mac_client_to_server,
      :mac_server_to_client,
      :compression_client_to_server,
      :compression_server_to_client,
      :languages_client_to_server,
      :languages_server_to_client,
    ].freeze

    # Messages

    SSH_MSG_DISCONNECT      = 1
    SSH_MSG_IGNORE          = 2
    SSH_MSG_UNIMPLEMENTED   = 3
    SSH_MSG_DEBUG           = 4
    SSH_MSG_SERVICE_REQUEST = 5
    SSH_MSG_SERVICE_ACCEPT  = 6

    SSH_MSG_KEXINIT         = 20
    SSH_MSG_NEWKEYS         = 21

    # http://tools.ietf.org/html/rfc5656#section-7.1
    SSH_MSG_KEX_ECDH_INIT      = 30
    SSH_MSG_KEX_ECDH_REPLY     = 31
    SSH_MSG_KEX_DH_GEX_REQUEST = 34
    SSH_MSG_KEX_DH_GEX_GROUP   = 31
    SSH_MSG_KEX_DH_GEX_INIT    = 32
    SSH_MSG_KEX_DH_GEX_REPLY   = 33
  end
end
