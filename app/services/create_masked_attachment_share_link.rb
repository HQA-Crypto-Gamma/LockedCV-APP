# frozen_string_literal: true

module LockedCV
  # Creates a share link for one saved masked PDF version through LockedCV-API.
  class CreateMaskedAttachmentShareLink
    class UnauthorizedError < StandardError; end
    class NotFoundError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(attachment_id:, masked_attachment_id:, auth_token:)
      response = @client.post(
        "/attachments/#{attachment_id}/masked_attachments/#{masked_attachment_id}/share_links",
        {},
        auth_token:
      )
      response.fetch('data').fetch('attributes')
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
      ServiceUnavailableError.new("Masked attachment share link API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
