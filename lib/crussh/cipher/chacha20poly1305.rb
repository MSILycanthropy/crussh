# frozen_string_literal: true

module Crussh
  module Cipher
    class ChaCha20Poly1305 < Algorithm
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

        def build_nonce(sequence)
          "\x00\x00\x00\x00" + [sequence].pack("Q>")
        end

        def chacha20_cipher
          cipher = OpenSSL::Cipher.new("chacha20")
          cipher.encrypt
          cipher
        end

        def chacha20_block(key, nonce, counter)
          cipher = chacha20_cipher
          cipher.key = key
          cipher.iv = [counter].pack("V") + nonce
          cipher
        end

        def generate_poly_key(sequence)
          nonce = build_nonce(sequence)
          cipher = chacha20_block(@main_key, nonce, 0)
          cipher.update("\x00" * 64)[0, 32]
        end
      end

      class OpeningKey < Key
        def decrypt_length(sequence, encrypted_length)
          nonce = build_nonce(sequence)
          cipher = chacha20_block(@header_key, nonce, 0)
          cipher.update(encrypted_length)
        end

        def open(sequence, encrypted_length, ciphertext, tag)
          poly_key = generate_poly_key(sequence)
          data = encrypted_length + ciphertext

          unless Crypto::Poly1305.verify(poly_key, tag, data)
            raise DecryptionError, "Poly1305 authentication failed"
          end

          nonce = build_nonce(sequence)
          cipher = chacha20_block(@main_key, nonce, 1)
          cipher.update(ciphertext)
        end
      end

      class SealingKey < Key
        def encrypt_length(sequence, length_bytes)
          nonce = build_nonce(sequence)
          cipher = chacha20_block(@header_key, nonce, 0)
          cipher.update(length_bytes)
        end

        def seal(sequence, encrypted_length, plaintext)
          nonce = build_nonce(sequence)
          cipher = chacha20_block(@main_key, nonce, 1)
          ciphertext = cipher.update(plaintext)

          poly_key = generate_poly_key(sequence)
          tag = Crypto::Poly1305.auth(poly_key, encrypted_length + ciphertext)

          [ciphertext, tag]
        end
      end
    end
  end
end
