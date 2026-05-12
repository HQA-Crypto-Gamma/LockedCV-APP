# frozen_string_literal: true

module LockedCV
  # Updates account profile details through LockedCV-API
  class UpdateAccount
    include BirthdayValidator

    class ValidationError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    EDITABLE_FIELDS = %i[
      email phone_number first_name last_name birthday address identification_numbers
    ].freeze
    OPTIONAL_FIELDS = EDITABLE_FIELDS - %i[email]

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(account_id:, profile_data:)
      validate!(profile_data)

      response = @client.put("/accounts/#{account_id}", profile_payload(profile_data))
      response.fetch('data').fetch('data').fetch('attributes')
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def profile_payload(profile_data)
      EDITABLE_FIELDS.to_h do |field|
        [field, payload_value(profile_data, field)]
      end
    end

    def validate!(profile_data)
      raise ValidationError, 'Email is required' if profile_data[:email].to_s.strip.empty?

      validate_birthday!(profile_data[:birthday])
    end

    def payload_value(profile_data, field)
      value = profile_data[field]
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
      details = [error.class, error.message].compact.join(': ')
      ServiceUnavailableError.new("Account update API unavailable: #{details}")
    end
  end
end
