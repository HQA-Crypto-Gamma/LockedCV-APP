# frozen_string_literal: true

module LockedCV
  # Fetches one account through LockedCV-API
  class FindAccount
    class NotFoundError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(account_id:)
      response = @client.get("/accounts/#{account_id}")
      response.fetch('data').fetch('attributes')
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
      details = [error.class, error.message].compact.join(': ')
      ServiceUnavailableError.new("Account API unavailable: #{details}")
    end
  end
end
