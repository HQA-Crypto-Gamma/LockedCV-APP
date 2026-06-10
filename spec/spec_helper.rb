# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/rg'
require 'webmock/minitest'

require_relative 'test_load_all'

API_URL = app.config.API_URL

def current_account(roles: ['admin'])
  account_info = {
    'type' => 'authenticated_account',
    'attributes' => {
      'id' => 'account-id',
      'username' => 'ada-lovelace',
      'email' => 'ada@example.com',
      'roles' => roles
    }
  }

  LockedCV::Account.new(account_info, 'auth-token')
end

def signed_data(request)
  JSON.parse(request.body).fetch('data')
end
