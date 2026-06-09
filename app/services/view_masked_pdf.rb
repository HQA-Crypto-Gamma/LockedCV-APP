# frozen_string_literal: true

module LockedCV
  # Fetches an inline masked PDF for read-only viewing through LockedCV-API.
  class ViewMaskedPdf
    class UnauthorizedError < StandardError; end
    class NotFoundError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(attachment_id:, masked_attachment_id:, auth_token:)
      @client.get_binary(
        "/attachments/#{attachment_id}/masked_attachments/#{masked_attachment_id}/view",
        auth_token:
      )
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError => e
      raise unavailable_error_for(e)
    end

    private

    def api_error_for(error)
      return UnauthorizedError.new(error.message) if [401, 403].include?(error.status)
      return NotFoundError.new(error.message) if error.status == 404

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Masked PDF view API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
