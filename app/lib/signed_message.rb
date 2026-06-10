# frozen_string_literal: true

require 'base64'
require 'json'
require 'rbnacl'

module LockedCV
  # Signs JSON-serializable API request bodies with the App's private key.
  module SignedMessage
    class KeypairError < StandardError; end

    module_function

    def setup(signing_key64)
      raise KeypairError, 'Missing SIGNING_KEY' if signing_key64.to_s.empty?

      @signing_key = Base64.strict_decode64(signing_key64)
    rescue StandardError => e
      raise KeypairError, e.message
    end

    def sign(message)
      raise KeypairError, 'SIGNING_KEY not configured' unless @signing_key

      signature = RbNaCl::SigningKey.new(@signing_key).sign(message.to_json)

      {
        data: message,
        signature: Base64.strict_encode64(signature)
      }
    end
  end
end
