# frozen_string_literal: true

module Crussh
  module Kex
    STRICT_SERVER = "kex-strict-s-v00@openssh.com"
    STRICT_CLIENT = "kex-strict-c-v00@openssh.com"

    EXT_INFO_SERVER = "ext-info-s"
    EXT_INFO_CLIENT = "ext-info-c"

    CURVE25519_SHA256 = "curve25519-sha256"
    CURVE25519_SHA256_LIBSSH = "curve25519-sha256@libssh.org"

    DEFAULT = [CURVE25519_SHA256, CURVE25519_SHA256_LIBSSH, STRICT_SERVER, EXT_INFO_SERVER]

    REGISTRY = {
      CURVE25519_SHA256 => Curve25519,
      CURVE25519_SHA256_LIBSSH => Curve25519,
    }

    class << self
      def from_name(name)
        algorithm_class = REGISTRY[name]

        raise UnknownAlgorithm, "Unknown KEX algorithm: #{name}" if algorithm_class.nil?

        algorithm_class.new
      end
    end

    Parameters = Data.define(
      :client_id,
      :server_id,
      :client_kexinit,
      :server_kexinit,
      :server_host_key,
      :client_public,
      :server_public,
      :shared_secret,
    )
  end
end
