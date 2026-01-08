# frozen_string_literal: true

require "zeitwerk"
require "securerandom"
require "async"
require "io/endpoint"
require "io/endpoint/host_endpoint"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("chacha20poly1305" => "ChaCha20Poly1305")
loader.ignore("#{__dir__}/crussh/crypto")
loader.setup

begin
  RUBY_VERSION =~ /(\d+\.\d+)/
  require "crussh/crypto/#{Regexp.last_match(1)}/poly1305"
rescue LoadError
  require "crussh/crypto/poly1305"
end

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

  class Error < StandardError; end

  class ConfigError < Error; end
  class ProtocolError < Error; end

  class PacketError < Error; end
  class PacketTooLarge < PacketError; end
  class PacketTooSmall < PacketError; end
  class InvalidPadding < PacketError; end
  class IncompletePacket < PacketError; end

  class NegotiationError < ProtocolError; end

  class KexError < ProtocolError; end

  class ConnectionError < Error; end
  class TimeoutError < ConnectionError; end
  class ConnectionClosed < ConnectionError; end

  class CryptoError < Error; end
  class UnknownAlgorithm < CryptoError; end
  class DecryptionError < CryptoError; end
  class SignatureError < CryptoError; end
  class KeyError < CryptoError; end

  class ChannelError < Error; end
  class ChannelClosed < ChannelError; end
  class ChannelWindowExhausted < ChannelError; end
end
