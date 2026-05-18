# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ChangePassword service' do
  before do
    @current_account = current_account
    @password_data = {
      current_password: 'old-secret',
      password: 'new-secret',
      password_confirmation: 'new-secret'
    }
  end

  it 'HAPPY: sends password update payload to API' do
    stub_request(:put, "#{API_URL}/account/password")
      .with(
        body: { current_password: 'old-secret', password: 'new-secret' }.to_json,
        headers: { 'Authorization' => 'Bearer auth-token' }
      )
      .to_return(status: 200, body: { message: 'Password updated' }.to_json)

    LockedCV::ChangePassword.new(app.config, current_account: @current_account).call(password_data: @password_data)
  end

  it 'BAD: validates required password fields before calling API' do
    _(
      proc do
        LockedCV::ChangePassword.new(app.config, current_account: @current_account).call(
          password_data: @password_data.merge(password: '')
        )
      end
    ).must_raise LockedCV::ChangePassword::ValidationError
  end

  it 'BAD: validates password confirmation before calling API' do
    _(
      proc do
        LockedCV::ChangePassword.new(app.config, current_account: @current_account).call(
          password_data: @password_data.merge(password_confirmation: 'wrong-secret')
        )
      end
    ).must_raise LockedCV::ChangePassword::ValidationError
  end
end
