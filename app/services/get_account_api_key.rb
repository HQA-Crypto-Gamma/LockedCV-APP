# frozen_string_literal: true

module LockedCV
  # Fetches a read-only API key for the current account.
  class GetAccountApiKey
    class NotFoundError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config, current_account:)
      @client = ApiClient.new(config)
      @current_account = current_account
    end

    def call(username: @current_account.username)
      response = @client.get(
        "/accounts/#{username}",
        auth_token: @current_account.auth_token
      )
      response.fetch('data').fetch('attributes').fetch('auth_token')
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def api_error_for(error)
      return NotFoundError.new(error.message) if error.status == 404

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Account API key unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
