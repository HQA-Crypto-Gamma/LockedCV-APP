# frozen_string_literal: true

module LockedCV
  # Fetches accounts from LockedCV-API for admin settings
  class ListAccounts
    class UnauthorizedError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account_id:)
      response = @client.get('/accounts', { current_account_id: })
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
