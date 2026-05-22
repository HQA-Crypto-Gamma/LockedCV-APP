# frozen_string_literal: true

module LockedCV
  # Updates an account's system role through LockedCV-API
  class AssignSystemRole
    class UnauthorizedError < StandardError; end
    class ValidationError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config, current_account:)
      @client = ApiClient.new(config)
      @current_account = current_account
    end

    def call(target_username:, role_name:)
      response = @client.put(
        "/accounts/#{target_username}/system_roles/#{role_name}",
        {},
        auth_token: @current_account.auth_token
      )
      response.fetch('data').fetch('data').fetch('attributes')
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def api_error_for(error)
      return UnauthorizedError.new(error.message) if [401, 403].include?(error.status)
      return ValidationError.new(error.message) if [400, 404].include?(error.status)

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      details = [error.class, error.message].compact.join(': ')
      ServiceUnavailableError.new("System role API unavailable: #{details}")
    end
  end
end
