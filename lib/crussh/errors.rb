# frozen_string_literal: true

module Crussh
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
end
