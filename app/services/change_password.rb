# frozen_string_literal: true

module LockedCV
  # Updates an account password through LockedCV-API.
  class ChangePassword
    class ValidationError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config, current_account:)
      @client = ApiClient.new(config)
      @current_account = current_account
    end

    def call(password_data:)
      validate!(password_data)

      @client.put(
        '/account/password',
        password_payload(password_data),
        auth_token: @current_account.auth_token
      )
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def validate!(password_data)
      if password_data[:current_password].to_s.empty? || password_data[:password].to_s.empty?
        raise ValidationError, 'Current password and new password are required'
      end

      return if password_data[:password] == password_data[:password_confirmation]

      raise ValidationError, 'Password confirmation does not match'
    end

    def password_payload(password_data)
      {
        current_password: password_data[:current_password],
        password: password_data[:password]
      }
    end

    def api_error_for(error)
      return ValidationError.new(error.message) if error.status == 400

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      details = [error.class, error.message].compact.join(': ')
      ServiceUnavailableError.new("Password update API unavailable: #{details}")
    end
  end
end
