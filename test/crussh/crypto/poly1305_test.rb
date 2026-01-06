# frozen_string_literal: true

# test/crussh/crypto/poly1305_test.rb

require "test_helper"

module Crussh
  module Crypto
    class Poly1305Test < Minitest::Test
      def setup
        @key = "\x01\x02\x03\x04" * 8
        @message = "Hello, World!"
      end

      def test_key_size_is_32
        assert_equal(32, Crussh::Crypto::Poly1305::KEY_SIZE)
      end

      def test_tag_size_is_16
        assert_equal(16, Crussh::Crypto::Poly1305::TAG_SIZE)
      end

      def test_auth_returns_16_byte_tag
        tag = Crussh::Crypto::Poly1305.auth(@key, @message)
        assert_equal(16, tag.bytesize)
      end

      def test_auth_returns_consistent_tags
        tag1 = Crussh::Crypto::Poly1305.auth(@key, @message)
        tag2 = Crussh::Crypto::Poly1305.auth(@key, @message)
        assert_equal(tag1, tag2)
      end

      def test_auth_returns_different_tags_for_different_messages
        tag1 = Crussh::Crypto::Poly1305.auth(@key, "message1")
        tag2 = Crussh::Crypto::Poly1305.auth(@key, "message2")
        refute_equal(tag1, tag2)
      end

      def test_auth_returns_different_tags_for_different_keys
        key1 = "\x01\x02\x03\x04" * 8
        key2 = "\x05\x06\x07\x08" * 8
        tag1 = Crussh::Crypto::Poly1305.auth(key1, @message)
        tag2 = Crussh::Crypto::Poly1305.auth(key2, @message)
        refute_equal(tag1, tag2)
      end

      def test_auth_raises_for_invalid_key_size
        error = assert_raises(ArgumentError) do
          Crussh::Crypto::Poly1305.auth("short", @message)
        end
        assert_match(/key must be 32 bytes/, error.message)
      end

      def test_auth_handles_empty_message
        tag = Crussh::Crypto::Poly1305.auth(@key, "")
        assert_equal(16, tag.bytesize)
      end

      def test_auth_handles_binary_data
        binary_message = (0..255).map(&:chr).join
        tag = Crussh::Crypto::Poly1305.auth(@key, binary_message)
        assert_equal(16, tag.bytesize)
      end

      def test_verify_returns_true_for_valid_tag
        tag = Crussh::Crypto::Poly1305.auth(@key, @message)
        assert(Crussh::Crypto::Poly1305.verify(@key, tag, @message))
      end

      def test_verify_returns_false_for_invalid_tag
        tag = Crussh::Crypto::Poly1305.auth(@key, @message)
        bad_tag = tag.dup
        bad_tag[0] = (bad_tag.getbyte(0) ^ 0xff).chr
        refute(Crussh::Crypto::Poly1305.verify(@key, bad_tag, @message))
      end

      def test_verify_returns_false_for_wrong_message
        tag = Crussh::Crypto::Poly1305.auth(@key, @message)
        refute(Crussh::Crypto::Poly1305.verify(@key, tag, "wrong message"))
      end

      def test_verify_returns_false_for_wrong_key
        tag = Crussh::Crypto::Poly1305.auth(@key, @message)
        wrong_key = "\x05\x06\x07\x08" * 8
        refute(Crussh::Crypto::Poly1305.verify(wrong_key, tag, @message))
      end

      def test_verify_raises_for_invalid_key_size
        error = assert_raises(ArgumentError) do
          Crussh::Crypto::Poly1305.verify("short", "\x00" * 16, @message)
        end
        assert_match(/key must be 32 bytes/, error.message)
      end

      def test_verify_raises_for_invalid_tag_size
        error = assert_raises(ArgumentError) do
          Crussh::Crypto::Poly1305.verify(@key, "short", @message)
        end
        assert_match(/tag must be 16 bytes/, error.message)
      end

      def test_rfc8439_test_vector
        key = [
          "85d6be7857556d337f4452fe42d506a8",
          "0103808afb0db2fd4abff6af4149f51b",
        ].join.scan(/../).map { |h| h.to_i(16).chr }.join

        message = "Cryptographic Forum Research Group"

        expected_tag = "a8061dc1305136c6c22b8baf0c0127a9"
          .scan(/../).map { |h| h.to_i(16).chr }.join

        tag = Crussh::Crypto::Poly1305.auth(key, message)
        assert_equal(expected_tag.unpack1("H*"), tag.unpack1("H*"))
      end

      def test_rfc8439_test_vector_verifies
        key = [
          "85d6be7857556d337f4452fe42d506a8",
          "0103808afb0db2fd4abff6af4149f51b",
        ].join.scan(/../).map { |h| h.to_i(16).chr }.join

        message = "Cryptographic Forum Research Group"

        expected_tag = "a8061dc1305136c6c22b8baf0c0127a9"
          .scan(/../).map { |h| h.to_i(16).chr }.join

        assert(Crussh::Crypto::Poly1305.verify(key, expected_tag, message))
      end
    end
  end
end
