# frozen_string_literal: true

module LockedCV
  # Registers a new account through LockedCV-API
  class RegisterAccount
    include BirthdayValidator

    class ValidationError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    REGISTRATION_FIELDS = %i[
      username email phone_number first_name last_name birthday address
      identification_numbers password
    ].freeze
    OPTIONAL_FIELDS = %i[
      phone_number first_name last_name birthday address identification_numbers
    ].freeze

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(registration_data)
      validate!(registration_data)

      response = @client.post('/accounts', registration_payload(registration_data))
      ApiClient.attributes_from(response)
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def registration_payload(registration_data)
      REGISTRATION_FIELDS.to_h do |field|
        [field, payload_value(registration_data, field)]
      end
    end

    def validate!(registration_data)
      if registration_data[:username].to_s.strip.empty? ||
         registration_data[:email].to_s.strip.empty? ||
         registration_data[:password].to_s.empty?
        raise ValidationError, 'Username, email, and password are required'
      end

      validate_birthday!(registration_data[:birthday])
    end

    def payload_value(registration_data, field)
      value = registration_data[field]
      OPTIONAL_FIELDS.include?(field) ? empty_to_nil(value) : value
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
      ServiceUnavailableError.new("Registration API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
