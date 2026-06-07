# frozen_string_literal: true

require_relative '../spec_helper'

describe 'AuthenticateGoogleSso service' do
  before do
    @id_token = 'google-id-token'
    @jwks = { keys: [{ kid: 'google-key' }] }
    @account_attributes = {
      'id' => 'account-id',
      'username' => 'google-user',
      'email' => 'google-user@example.com',
      'roles' => ['member'],
      'auth_token' => 'session-token'
    }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: sends the Google id token and JWKS to the API' do
    stub_google_jwks
    WebMock.stub_request(:post, "#{API_URL}/auth/sso")
           .with(body: { provider: 'google', id_token: @id_token, jwks: @jwks }.to_json)
           .to_return(
             status: 200,
             body: { data: { type: 'authenticated_account', attributes: @account_attributes } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    authenticated = LockedCV::AuthenticateGoogleSso.new(app.config).call(id_token: @id_token)

    _(authenticated).must_equal(
      account: {
        'type' => 'authenticated_account',
        'attributes' => @account_attributes.except('auth_token')
      },
      auth_token: 'session-token'
    )
  end

  it 'BAD: rejects a missing id token without calling Google or the API' do
    _(proc {
      LockedCV::AuthenticateGoogleSso.new(app.config).call(id_token: '')
    }).must_raise LockedCV::AuthenticateGoogleSso::UnauthorizedError

    assert_not_requested(:get, app.config.GOOGLE_JWKS_URL)
    assert_not_requested(:post, "#{API_URL}/auth/sso")
  end

  it 'BAD: raises UnauthorizedError when the API rejects the SSO token' do
    stub_google_jwks
    WebMock.stub_request(:post, "#{API_URL}/auth/sso")
           .to_return(status: 401, body: { message: 'Invalid SSO token' }.to_json)

    _(proc {
      LockedCV::AuthenticateGoogleSso.new(app.config).call(id_token: @id_token)
    }).must_raise LockedCV::AuthenticateGoogleSso::UnauthorizedError
  end

  it 'BAD: raises ServiceUnavailableError when Google JWKS fails' do
    WebMock.stub_request(:get, app.config.GOOGLE_JWKS_URL)
           .to_return(status: 500, body: { error: 'unavailable' }.to_json)

    _(proc {
      LockedCV::AuthenticateGoogleSso.new(app.config).call(id_token: @id_token)
    }).must_raise LockedCV::AuthenticateGoogleSso::ServiceUnavailableError
  end

  def stub_google_jwks
    WebMock.stub_request(:get, app.config.GOOGLE_JWKS_URL)
           .to_return(
             status: 200,
             body: @jwks.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
