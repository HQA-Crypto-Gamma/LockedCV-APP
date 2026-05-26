# frozen_string_literal: true

require_relative 'form_base'

module LockedCV
  module Form
    AssignSystemRole = Dry::Validation.Contract do
      params do
        required(:username).filled(:string)
        required(:role).filled(:string)
      end

      rule(:role) do
        key.failure('must be a known system role') unless SYSTEM_ROLES.include?(value)
      end
    end
  end
end
