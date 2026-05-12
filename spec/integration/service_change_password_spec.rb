# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ChangePassword service' do
  before do
    @password_data = {
      current_password: 'old-secret',
      password: 'new-secret',
      password_confirmation: 'new-secret'
    }
  end

  it 'HAPPY: sends password update payload to API' do
    stub_request(:put, "#{API_URL}/accounts/acct-1/password")
      .with(body: { current_password: 'old-secret', password: 'new-secret' }.to_json)
      .to_return(status: 200, body: { message: 'Password updated' }.to_json)

    LockedCV::ChangePassword.new(app.config).call(
      account_id: 'acct-1',
      password_data: @password_data
    )
  end

  it 'BAD: validates required password fields before calling API' do
    _(
      proc do
        LockedCV::ChangePassword.new(app.config).call(
          account_id: 'acct-1',
          password_data: @password_data.merge(password: '')
        )
      end
    ).must_raise LockedCV::ChangePassword::ValidationError
  end

  it 'BAD: validates password confirmation before calling API' do
    _(
      proc do
        LockedCV::ChangePassword.new(app.config).call(
          account_id: 'acct-1',
          password_data: @password_data.merge(password_confirmation: 'wrong-secret')
        )
      end
    ).must_raise LockedCV::ChangePassword::ValidationError
  end
end
