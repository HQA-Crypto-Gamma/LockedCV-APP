# frozen_string_literal: true

require 'date'

module LockedCV
  # Validates optional birthday values before sending account data to the API
  module BirthdayValidator
    BIRTHDAY_FORMAT_ERROR = 'Birthday must use YYYY-MM-DD format'

    private

    def validate_birthday!(birthday)
      cleaned = birthday.to_s.strip
      return if cleaned.empty?

      raise validation_error unless cleaned.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      Date.iso8601(cleaned)
    rescue Date::Error
      raise validation_error
    end

    def validation_error
      self.class::ValidationError.new(BIRTHDAY_FORMAT_ERROR)
    end
  end
end
