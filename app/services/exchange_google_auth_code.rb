# frozen_string_literal: true

require 'http'
require 'json'

module LockedCV
  # Exchanges a Google authorization code for an OpenID Connect id_token.
  class ExchangeGoogleAuthCode
    class TokenExchangeError < StandardError; end

    def initialize(config)
      @google = GoogleSsoConfig.new(config)
    end

    def call(code)
      raise TokenExchangeError, 'Missing authorization code' if code.to_s.empty?

      response = HTTP.headers(accept: 'application/json').post(
        google.token_url,
        form: token_request_body(code)
      )
      parsed = parse_response(response)
      parsed.fetch('id_token')
    rescue KeyError, JSON::ParserError, HTTP::Error => e
      raise TokenExchangeError, "Google token exchange failed: #{e.message}"
    end

    private

    attr_reader :google

    def token_request_body(code)
      {
        client_id: google.client_id,
        client_secret: google.client_secret,
        code:,
        grant_type: 'authorization_code',
        redirect_uri: google.redirect_uri
      }
    end

    def parse_response(response)
      parsed = JSON.parse(response.body.to_s)
      return parsed if (200..299).cover?(response.code)

      raise TokenExchangeError, parsed['error_description'] || parsed['error'] || 'Google token exchange rejected'
    end
  end
end
