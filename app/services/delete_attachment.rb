# frozen_string_literal: true

module LockedCV
  # Deletes a CV attachment through LockedCV-API.
  class DeleteAttachment
    class UnauthorizedError < StandardError; end
    class NotFoundError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(attachment_id:, auth_token:)
      @client.delete(
        "/attachments/#{attachment_id}",
        {},
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
      details = [error.class, error.message].compact.join(': ')
      ServiceUnavailableError.new("Delete attachment API unavailable: #{details}")
    end
  end
end
