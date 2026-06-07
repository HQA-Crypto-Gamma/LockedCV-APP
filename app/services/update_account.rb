# frozen_string_literal: true

module LockedCV
  # Updates account profile details through LockedCV-API
  class UpdateAccount
    class ValidationError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    EDITABLE_FIELDS = %i[
      email phone_number first_name last_name birthday address identification_numbers
    ].freeze
    OPTIONAL_FIELDS = EDITABLE_FIELDS - %i[email]

    def initialize(config, current_account:)
      @client = ApiClient.new(config)
      @current_account = current_account
    end

    def call(profile_data:)
      response = update_account(profile_data)
      ApiClient.attributes_from(response)
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError, KeyError => e
      raise unavailable_error_for(e)
    end

    private

    def update_account(profile_data)
      @client.put(
        '/account',
        profile_payload(profile_data),
        auth_token: @current_account.auth_token
      )
    end

    def profile_payload(profile_data)
      EDITABLE_FIELDS.to_h do |field|
        [field, payload_value(profile_data, field)]
      end
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
      ServiceUnavailableError.new("Account update API unavailable: #{ApiClient.error_details(error)}")
    end
  end
end
