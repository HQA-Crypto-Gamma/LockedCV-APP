# frozen_string_literal: true

module LockedCV
  # Fetches the masked text preview and detected fields for one attachment.
  class GetMaskedAttachmentText
    class UnauthorizedError < StandardError; end
    class NotFoundError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(attachment_id:, auth_token:)
      response = @client.get(
        "/attachments/#{attachment_id}/masked_text",
        auth_token:
      )
      ScanResult.new(response.fetch('data').fetch('attributes'))
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def api_error_for(error)
      case error.status
      when 401, 403
        UnauthorizedError.new(error.message)
      when 404
        NotFoundError.new(error.message)
      else
        unavailable_error_for(error)
      end
    end

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Attachment scan API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
