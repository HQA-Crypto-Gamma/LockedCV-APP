# frozen_string_literal: true

require 'base64'
require 'json'
require 'rbnacl'

module LockedCV
  # Encrypts and decrypts JSON-serializable values for server-side sessions.
  class SecureMessage
    class << self
      attr_reader :key

      def encoded_random_bytes(length)
        Base64.strict_encode64(RbNaCl::Random.random_bytes(length))
      end

      def generate_key
        encoded_random_bytes(RbNaCl::SecretBox.key_bytes)
      end

      def setup(msg_key)
        @key = Base64.strict_decode64(msg_key)
      end

      def encrypt(message)
        raise 'message missing' unless message

        message_json = message.to_json
        simple_box = RbNaCl::SimpleBox.from_secret_key(key)
        ciphertext = simple_box.encrypt(message_json)
        new(Base64.urlsafe_encode64(ciphertext))
      end
    end

    def initialize(ciphertext64)
      @message_secure = ciphertext64
    end

    def to_s
      @message_secure
    end

    def decrypt
      ciphertext = Base64.urlsafe_decode64(@message_secure)
      simple_box = RbNaCl::SimpleBox.from_secret_key(self.class.key)
      message_json = simple_box.decrypt(ciphertext)
      JSON.parse(message_json)
    end
  end
end
