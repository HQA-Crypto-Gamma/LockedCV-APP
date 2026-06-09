# frozen_string_literal: true

module LockedCV
  # Fetches masked PDFs shared with the signed-in account.
  class ListSharedMaskedAttachments
    class ServiceUnavailableError < StandardError; end

    def initialize(config, current_account:)
      @client = ApiClient.new(config)
      @current_account = current_account
    end

    def call
      response = @client.get(
        '/shared_masked_attachments',
        auth_token: @current_account.auth_token
      )
      response.fetch('data').map { |entry| SharedMaskedAttachment.new(entry) }
    rescue ApiClient::ApiError, HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Shared masked attachments API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
