# frozen_string_literal: true

require_relative '../spec_helper'

describe LockedCV::CurrentSession do
  def account_info
    {
      'type' => 'authenticated_account',
      'attributes' => {
        'id' => 'account-id',
        'username' => 'ada-lovelace',
        'email' => 'ada@example.com',
        'roles' => ['member']
      }
    }
  end

  it 'HAPPY: stores and loads current account through secure session' do
    rack_session = {}
    current_session = LockedCV::CurrentSession.new(rack_session)
    account = LockedCV::Account.new(account_info, 'auth-token')

    current_session.current_account = account
    stored = current_session.current_account

    _(stored.logged_in?).must_equal true
    _(stored.username).must_equal 'ada-lovelace'
    _(stored.auth_token).must_equal 'auth-token'
  end

  it 'HAPPY: deletes account info and auth token' do
    rack_session = {}
    current_session = LockedCV::CurrentSession.new(rack_session)
    current_session.current_account = LockedCV::Account.new(account_info, 'auth-token')

    current_session.delete

    _(current_session.current_account.logged_out?).must_equal true
  end
end
