# frozen_string_literal: true

require_relative 'secure_message'

module LockedCV
  # Stores session values as SecureMessage ciphertexts.
  class SecureSession
    SESSION_SECRET_BYTES = 64

    class << self
      def generate_secret
        SecureMessage.encoded_random_bytes(SESSION_SECRET_BYTES)
      end
    end

    def initialize(session)
      @session = session
    end

    def set(key, value)
      @session[key] = SecureMessage.encrypt(value).to_s
    end

    def get(key)
      return nil unless @session && @session[key]

      SecureMessage.new(@session[key]).decrypt
    end

    def delete(key)
      @session.delete(key)
    end
  end
end
