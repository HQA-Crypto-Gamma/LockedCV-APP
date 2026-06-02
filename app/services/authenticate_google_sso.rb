# frozen_string_literal: true

require 'http'
require 'json'
require_relative 'authenticated_account_response'

module LockedCV
  # Completes Google SSO by sending the id_token and provider JWKS to LockedCV-API.
  class AuthenticateGoogleSso
    class UnauthorizedError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
      @google = GoogleSsoConfig.new(config)
    end

    def call(id_token:)
      raise UnauthorizedError, 'Missing Google id token' if id_token.to_s.empty?

      response = @client.post('/auth/sso', { provider: 'google', id_token:, jwks: google_jwks })
      AuthenticatedAccountResponse.from(response)
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    attr_reader :google

    def google_jwks
      response = HTTP.headers(accept: 'application/json').get(google.jwks_url)
      parsed = JSON.parse(response.body.to_s)
      raise ServiceUnavailableError, 'Google JWKS request failed' unless (200..299).cover?(response.code)

      parsed.fetch('keys')
      parsed
    end

    def api_error_for(error)
      return UnauthorizedError.new("Google SSO rejected: #{error.message}") if error.status == 401

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Google SSO unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
