# frozen_string_literal: true

module LockedCV
  # Deletes an account through LockedCV-API for admin settings.
  class DeleteAccount
    class UnauthorizedError < StandardError; end
    class ValidationError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config, current_account:)
      @client = ApiClient.new(config)
      @current_account = current_account
    end

    def call(target_account_id:)
      @client.delete(
        "/accounts/#{target_account_id}",
        auth_token: @current_account.auth_token
      )
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError => e
      raise unavailable_error_for(e)
    end

    private

    def api_error_for(error)
      return UnauthorizedError.new(error.message) if [401, 403].include?(error.status)
      return ValidationError.new(error.message) if error.status == 404

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      details = [error.class, error.message].compact.join(': ')
      ServiceUnavailableError.new("Delete account API unavailable: #{details}")
    end
  end
end
