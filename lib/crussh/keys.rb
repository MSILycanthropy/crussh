# frozen_string_literal: true

require "ed25519"
require "ssh_data"

module Crussh
  module Keys
    ED25519    = "ssh-ed25519"
    RSA_SHA256 = "rsa-sha2-256"
    RSA_SHA512 = "rsa-sha2-512"
    ECDSA_P256 = "ecdsa-sha2-nistp256"
    ECDSA_P384 = "ecdsa-sha2-nistp384"
    ECDSA_P521 = "ecdsa-sha2-nistp521"

    DEFAULT = [
      ED25519,
      RSA_SHA512,
      RSA_SHA256,
      ECDSA_P521,
      ECDSA_P384,
      ECDSA_P256,
    ]

    class << self
      def generate(algorithm = ED25519)
        private_key = case algorithm
        when ED25519
          SSHData::PrivateKey::ED25519.generate
        when RSA_SHA256, RSA_SHA512
          SSHData::PrivateKey::RSA.generate
        when ECDSA_P256
          SSHData::PrivateKey::ECDSA.generate("nistp256")
        when ECDSA_P384
          SSHData::PrivateKey::ECDSA.generate("nistp384")
        when ECDSA_P521
          SSHData::PrivateKey::ECDSA.generate("nistp521")
        else
          raise KeyError, "Unknown algorithm: #{algorithm}"
        end

        KeyPair.new(private_key, signature_algorithm: algorithm)
      end

      def from_openssh(data, passphrase: nil)
        private_key = SSHData::PrivateKey.parse_openssh(data, passphrase:)
        KeyPair.new(private_key)
      rescue SSHData::DecryptError
        raise KeyError, "Invalid passphrase or corrupted key"
      rescue SSHData::DecodeError => e
        raise KeyError, "Failed to parse key: #{e.message}"
      end

      def from_file(path, passphrase: nil)
        from_openssh(File.read(path), passphrase:)
      end

      def parse_public_blob(data)
        public_key = SSHData::PublicKey.parse(data)

        PublicKey.new(public_key)
      rescue SSHData::DecodeError => e
        raise KeyError, "Failed to parse public key: #{e.message}"
      end

      def parse_authorized_key(data)
        public_key = SSHData::PublicKey.parse_openssh(data)
        PublicKey.new(public_key)
      rescue SSHData::DecodeError => e
        raise KeyError, "Failed to parse public key: #{e.message}"
      end
    end
  end
end
