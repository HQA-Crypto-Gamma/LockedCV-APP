# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ChangePassword service' do
  before do
    @current_account = current_account
    @password_data = {
      current_password: 'old-secret',
      password: 'new-secret'
    }
  end

  it 'HAPPY: sends password update payload without form-only fields to API' do
    stub_request(:put, "#{API_URL}/account/password")
      .with(
        body: { current_password: 'old-secret', password: 'new-secret' }.to_json,
        headers: { 'Authorization' => 'Bearer auth-token' }
      )
      .to_return(status: 200, body: { message: 'Password updated' }.to_json)

    LockedCV::ChangePassword.new(app.config, current_account: @current_account).call(password_data: @password_data)

    assert_requested(:put, "#{API_URL}/account/password", body: { current_password: 'old-secret', password: 'new-secret' }.to_json)
  end

  it 'BAD: raises ValidationError when API rejects password data' do
    stub_request(:put, "#{API_URL}/account/password")
      .with(
        body: { current_password: 'wrong-secret', password: 'new-secret' }.to_json,
        headers: { 'Authorization' => 'Bearer auth-token' }
      )
      .to_return(
        status: 400,
        body: { message: 'Current password is incorrect' }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    _(
      proc do
        LockedCV::ChangePassword.new(app.config, current_account: @current_account).call(
          password_data: @password_data.merge(current_password: 'wrong-secret')
        )
      end
    ).must_raise LockedCV::ChangePassword::ValidationError
  end
end
