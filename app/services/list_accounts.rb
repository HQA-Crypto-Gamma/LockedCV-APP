# frozen_string_literal: true

module LockedCV
  # Fetches accounts from LockedCV-API for admin settings
  class ListAccounts
    class UnauthorizedError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config, current_account:)
      @client = ApiClient.new(config)
      @current_account = current_account
    end

    def call
      response = @client.get('/accounts', auth_token: @current_account.auth_token)
      response.fetch('data').map { |entry| entry.fetch('attributes') }
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError => e
      raise unavailable_error_for(e)
    end

    private

    def api_error_for(error)
      return UnauthorizedError.new(error.message) if [401, 403].include?(error.status)

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      details = [error.class, error.message].compact.join(': ')
      ServiceUnavailableError.new("Accounts API unavailable: #{details}")
    end
  end
end
