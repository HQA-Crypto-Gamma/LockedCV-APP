# frozen_string_literal: true

require_relative 'authenticated_account_response'

module LockedCV
  # Authenticate credentials against LockedCV-API
  class AuthenticateAccount
    class UnauthorizedError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, password:)
      raise UnauthorizedError, 'Username and password required' if username.to_s.strip.empty? || password.to_s.empty?

      response = @client.post('/auth/authenticate', { username:, password: })
      account_response_from(response)
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError => e
      raise unavailable_error_for(e)
    end

    private

    def account_response_from(response)
      AuthenticatedAccountResponse.from(response)
    end

    def api_error_for(error)
      return UnauthorizedError.new("Authentication failed: #{error.message}") if error.status == 403

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Authentication API unavailable: #{error.message}")
    end
  end
end
