# frozen_string_literal: true

require_relative '../spec_helper'

describe 'AuthenticateAccount service' do
  before do
    @credentials = { username: 'ada-lovelace', password: 'ada-secret' }
    @account_attributes = {
      'id' => 'account-id',
      'username' => 'ada-lovelace',
      'email' => 'ada@example.com',
      'roles' => ['admin']
    }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: returns authenticated account attributes' do
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: @credentials.to_json)
           .to_return(
             status: 200,
             body: { data: { attributes: @account_attributes } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    account = LockedCV::AuthenticateAccount.new(app.config).call(**@credentials)

    _(account).must_equal @account_attributes
  end

  it 'BAD: raises UnauthorizedError when credentials are rejected' do
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: @credentials.to_json)
           .to_return(
             status: 403,
             body: { message: 'Invalid credentials' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::AuthenticateAccount.new(app.config).call(**@credentials)
    }).must_raise LockedCV::AuthenticateAccount::UnauthorizedError
  end

  it 'BAD: raises ServiceUnavailableError when API fails' do
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: @credentials.to_json)
           .to_return(
             status: 500,
             body: { message: 'boom' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::AuthenticateAccount.new(app.config).call(**@credentials)
    }).must_raise LockedCV::AuthenticateAccount::ServiceUnavailableError
  end
end
