# frozen_string_literal: true

module Crussh
  module Cipher
    class ChaCha20Poly1305 < Base
      KEY_LENGTH = 64

      def key_length = KEY_LENGTH
      def nonce_length = 0
      def block_size = 8
      def tag_length = 16

      def needs_mac? = false

      def make_opening_key(key:, nonce: nil, mac_key: nil, mac: nil)
        OpeningKey.new(key)
      end

      def make_sealing_key(key:, nonce: nil, mac_key: nil, mac: nil)
        SealingKey.new(key)
      end

      class Key
        def initialize(key)
          raise ArgumentError, "Key must be exactly #{KEY_LENGTH} bytes" unless key.bytesize == KEY_LENGTH

          @main_key = key[0, 32]
          @header_key = key[32, 32]
        end

        private

        def build_iv(sequence, counter = 0)
          [counter, 0, 0, sequence].pack("VNNNN")[0, 16]
        end

        def chacha20_cipher(encrypt:)
          cipher = OpenSSL::Cipher.new("chacha20")
          encrypt ? cipher.encrypt : cipher.decrypt
          cipher
        end

        def generate_poly_key(sequence)
          cipher = chacha20_cipher(encrypt: true)
          cipher.key = @main_key
          cipher.iv = build_iv(sequence, 0)
          cipher.update("\x00" * 32)
        end
      end

      class OpeningKey < Key
        def decrypt_length(sequence, encrypted_length)
          cipher = chacha20_cipher(encrypt: false)
          cipher.key = @header_key
          cipher.iv = build_iv(sequence)
          cipher.update(encrypted_length)
        end

        def open(sequence, encrypted_length, ciphertext, tag)
          poly_key = generate_poly_key(sequence)
          data = encrypted_length + ciphertext

          begin
            RbNaCl::OneTimeAuth.verify(poly_key, tag, data)
          rescue RbNaCl::BadAuthenticatorError
            raise DecryptionError, "Poly1305 authentication failed"
          end

          cipher = chacha20_cipher(encrypt: false)
          cipher.key = @main_key
          cipher.iv = build_iv(sequence, 1)
          cipher.update(ciphertext)
        end
      end

      class SealingKey < Key
        def encrypt_length(sequence, length_bytes)
          cipher = chacha20_cipher(encrypt: true)
          cipher.key = @header_key
          cipher.iv = build_iv(sequence, 0)
          cipher.update(length_bytes)
        end

        def seal(sequence, encrypted_length, plaintext)
          cipher = chacha20_cipher(encrypt: true)
          cipher.key = @main_key
          ciphertext = cipher.update(plaintext)

          poly_key = generate_poly_key(sequence)
          tag = RbNaCl::OneTimeAuth.auth(poly_key, encrypted_length + ciphertext)

          [ciphertext, tag]
        end
      end
    end
  end
end
