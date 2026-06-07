# frozen_string_literal: true

module LockedCV
  # Fetches a temporary masked PDF preview from LockedCV-API.
  class PreviewMaskedPdf
    class UnauthorizedError < StandardError; end
    class NotFoundError < StandardError; end
    class ValidationError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(attachment_id:, auth_token:, selected_labels:)
      @client.post_binary(
        "/attachments/#{attachment_id}/masked_attachments/preview",
        { selected_labels: },
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
      return ValidationError.new(error.message) if error.status == 400

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Masked PDF preview API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
