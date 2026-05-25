# frozen_string_literal: true

require 'date'
require 'dry-validation'

module LockedCV
  # Shared form-validation helpers and constants.
  module Form
    USERNAME_REGEX = /\A[A-Za-z0-9][A-Za-z0-9._-]{2,38}[A-Za-z0-9]\z/
    EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\z/
    PASSWORD_ENTROPY_MIN = 3.0
    SYSTEM_ROLES = %w[admin member].freeze

    module_function

    def validation_errors(validation)
      validation.errors.to_h.transform_values(&:first)
    end

    def message_values(validation)
      validation.values.to_h
    end

    def valid_birthday?(value)
      cleaned = value.to_s.strip
      return true if cleaned.empty?
      return false unless cleaned.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      Date.iso8601(cleaned)
      true
    rescue Date::Error
      false
    end

    def uploaded_value(uploaded_file, key)
      return uploaded_file[key] if uploaded_file.respond_to?(:key?) && uploaded_file.key?(key)
      return uploaded_file[key.to_s] if uploaded_file.respond_to?(:key?) && uploaded_file.key?(key.to_s)

      nil
    end
  end
end
