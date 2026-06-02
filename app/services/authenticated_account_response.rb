# frozen_string_literal: true

module LockedCV
  # Converts API authenticated_account responses into APP session data.
  module AuthenticatedAccountResponse
    module_function

    def from(response)
      data = response.fetch('data')
      attributes = data.fetch('attributes').dup
      auth_token = attributes.delete('auth_token')

      {
        account: {
          'type' => data.fetch('type'),
          'attributes' => attributes
        },
        auth_token:
      }
    end
  end
end
