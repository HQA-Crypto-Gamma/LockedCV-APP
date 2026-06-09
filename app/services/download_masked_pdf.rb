# frozen_string_literal: true

module LockedCV
  # Downloads a password-protected masked PDF attachment through LockedCV-API.
  class DownloadMaskedPdf
    class UnauthorizedError < StandardError; end
    class NotFoundError < StandardError; end
    class ValidationError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(attachment_id:, masked_attachment_id:, auth_token:, password:)
      @client.post_binary(
        "/attachments/#{attachment_id}/masked_attachments/#{masked_attachment_id}/encrypted_download",
        { password: },
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
      ServiceUnavailableError.new("Encrypted masked PDF download API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
