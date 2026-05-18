# frozen_string_literal: true

require_relative '../spec_helper'

describe LockedCV::Account do
  def account_info(roles: [])
    {
      'type' => 'authenticated_account',
      'attributes' => {
        'id' => 'account-id',
        'username' => 'ada-lovelace',
        'email' => 'ada@example.com',
        'roles' => roles
      }
    }
  end

  it 'HAPPY: treats account info and auth token as logged in' do
    account = LockedCV::Account.new(account_info, 'auth-token')

    _(account.logged_in?).must_equal true
    _(account.logged_out?).must_equal false
  end

  it 'HAPPY: treats missing account info or auth token as logged out' do
    account = LockedCV::Account.new(nil, nil)

    _(account.logged_in?).must_equal false
    _(account.logged_out?).must_equal true
  end

  it 'HAPPY: exposes account attributes from API account info' do
    account = LockedCV::Account.new(account_info, 'auth-token')

    _(account.id).must_equal 'account-id'
    _(account.username).must_equal 'ada-lovelace'
    _(account.email).must_equal 'ada@example.com'
  end

  it 'HAPPY: exposes role predicates' do
    admin = LockedCV::Account.new(account_info(roles: %w[admin]), 'auth-token')
    member = LockedCV::Account.new(account_info(roles: %w[member]), 'auth-token')

    _(admin.admin?).must_equal true
    _(admin.member?).must_equal false
    _(member.admin?).must_equal false
    _(member.member?).must_equal true
  end
end
