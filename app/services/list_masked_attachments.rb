# frozen_string_literal: true

module LockedCV
  # Fetches saved masked PDF versions for one attachment.
  class ListMaskedAttachments
    class UnauthorizedError < StandardError; end
    class NotFoundError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(attachment_id:, auth_token:)
      response = @client.get(
        "/attachments/#{attachment_id}/masked_attachments",
        auth_token:
      )
      response.fetch('data').map { |entry| MaskedAttachment.new(entry) }
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def api_error_for(error)
      return UnauthorizedError.new(error.message) if [401, 403].include?(error.status)
      return NotFoundError.new(error.message) if error.status == 404

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Masked attachment list API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
