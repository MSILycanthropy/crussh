# frozen_string_literal: true

require "securerandom"
require "async"
require "io/endpoint"
require "io/endpoint/host_endpoint"

require_relative "crussh/config"
require_relative "crussh/endpoint"
require_relative "crussh/errors"
require_relative "crussh/negotiator"
require_relative "crussh/protocol"
require_relative "crussh/server"
require_relative "crussh/ssh_id"
require_relative "crussh/version"

require_relative "crussh/kex/init"

require_relative "crussh/server/config"
require_relative "crussh/server/handler"
require_relative "crussh/server/session"

require_relative "crussh/transport/packet_stream"
require_relative "crussh/transport/reader"
require_relative "crussh/transport/version_exchange"
require_relative "crussh/transport/writer"

module Crussh
  Algorithms = Data.define(
    :kex,
    :host_key,
    :cipher_client_to_server,
    :cipher_server_to_client,
    :mac_client_to_server,
    :mac_server_to_client,
    :compression_client_to_server,
    :compression_server_to_client,
  )
end
