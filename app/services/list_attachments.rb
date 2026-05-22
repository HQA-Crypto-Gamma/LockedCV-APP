# frozen_string_literal: true

module LockedCV
  # Fetches CV attachment records for the signed-in account
  class ListAttachments
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(auth_token:)
      response = @client.get('/attachments', {}, auth_token:)
      response.fetch('data').map { |entry| entry.fetch('data').fetch('attributes') }
    rescue ApiClient::ApiError, HTTP::Error, JSON::ParserError => e
      raise unavailable_error_for(e)
    end

    private

    def unavailable_error_for(error)
      details = [error.class, error.message].compact.join(': ')
      ServiceUnavailableError.new("Attachments API unavailable: #{details}")
    end
  end
end
