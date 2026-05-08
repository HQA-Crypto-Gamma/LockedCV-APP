# frozen_string_literal: true

module LockedCV
  # Registers a new account through LockedCV-API
  class RegisterAccount
    class ValidationError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, email:, phone_number:, password:)
      validate!(username:, email:, password:)

      response = @client.post('/accounts', registration_payload(username:, email:, phone_number:, password:))
      response.fetch('data').fetch('data').fetch('attributes')
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def registration_payload(username:, email:, phone_number:, password:)
      {
        username:,
        email:,
        phone_number: empty_to_nil(phone_number),
        password:
      }
    end

    def validate!(username:, email:, password:)
      return unless username.to_s.strip.empty? || email.to_s.strip.empty? || password.to_s.empty?

      raise ValidationError, 'Username, email, and password are required'
    end

    def empty_to_nil(value)
      cleaned = value.to_s.strip
      cleaned.empty? ? nil : cleaned
    end

    def api_error_for(error)
      return ValidationError.new(error.message) if error.status == 400

      unavailable_error_for(error)
    end

    def unavailable_error_for(error)
      details = [error.class, error.message].compact.join(': ')
      ServiceUnavailableError.new("Registration API unavailable: #{details}")
    end
  end
end
