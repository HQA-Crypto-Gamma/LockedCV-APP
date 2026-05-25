# frozen_string_literal: true

require_relative 'form_base'

module LockedCV
  module Form
    LoginCredentials = Dry::Validation.Contract do
      params do
        required(:username).filled(:string)
        required(:password).filled(:string)
      end
    end

    RegistrationStart = Dry::Validation.Contract do
      params do
        required(:username).filled(:string)
        required(:email).filled(:string)
      end

      rule(:username) do
        key.failure('must be 4-40 ASCII letters, digits, dots, underscores, or hyphens') unless
          USERNAME_REGEX.match?(value)
      end

      rule(:email) do
        key.failure('must be a valid email address') unless EMAIL_REGEX.match?(value)
      end
    end

    RegistrationPassword = Dry::Validation.Contract do
      params do
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
