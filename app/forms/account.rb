# frozen_string_literal: true

require_relative 'form_base'

module LockedCV
  module Form
    AccountProfile = Dry::Validation.Contract do
      params do
        required(:email).filled(:string)
        optional(:phone_number).maybe(:string)
        optional(:first_name).maybe(:string, max_size?: 80)
        optional(:last_name).maybe(:string, max_size?: 80)
        optional(:birthday).maybe(:string)
        optional(:address).maybe(:string, max_size?: 200)
        optional(:identification_numbers).maybe(:string, max_size?: 80)
      end

      rule(:email) do
        key.failure('must be a valid email address') unless EMAIL_REGEX.match?(value)
      end

      rule(:birthday) do
        key.failure('must use YYYY-MM-DD format') unless Form.valid_birthday?(value)
      end
    end

    ChangePassword = Dry::Validation.Contract do
      params do
        required(:current_password).filled(:string)
        required(:password).filled(:string, min_size?: 8)
        required(:password_confirmation).filled(:string)
      end

      rule(:password) do
        entropy = LockedCV::StringSecurity.entropy(value)
        if entropy < PASSWORD_ENTROPY_MIN
          key.failure("is too predictable (entropy #{entropy.round(2)} < #{PASSWORD_ENTROPY_MIN})")
        end
      end

      rule(:password, :password_confirmation) do
        key(:password_confirmation).failure('does not match password') if
          values[:password] != values[:password_confirmation]
      end
    end
  end
end
