# frozen_string_literal: true

module LockedCV
  # Fetches CV attachment records for the signed-in account
  class ListAttachments
    class ServiceUnavailableError < StandardError; end

    def initialize(config, current_account:)
      @client = ApiClient.new(config)
      @current_account = current_account
    end

    def call
      response = @client.get(
        '/attachments',
        auth_token: @current_account.auth_token
      )
      response.fetch('data').map { |entry| Attachment.new(entry) }
    rescue ApiClient::ApiError, HTTP::Error, JSON::ParserError => e
      raise unavailable_error_for(e)
    end

    private

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Attachments API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
