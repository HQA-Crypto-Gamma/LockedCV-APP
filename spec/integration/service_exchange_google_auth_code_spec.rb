# frozen_string_literal: true

require 'uri'
require_relative '../spec_helper'

describe 'ExchangeGoogleAuthCode service' do
  after do
    WebMock.reset!
  end

  it 'HAPPY: exchanges an authorization code for an id token' do
    stub_google_token_exchange(
      status: 200,
      body: { id_token: 'google-id-token' }
    )

    id_token = LockedCV::ExchangeGoogleAuthCode.new(app.config).call('google-code')

    _(id_token).must_equal 'google-id-token'
  end

  it 'BAD: rejects a missing authorization code' do
    _(proc {
      LockedCV::ExchangeGoogleAuthCode.new(app.config).call('')
    }).must_raise LockedCV::ExchangeGoogleAuthCode::TokenExchangeError
  end

  it 'BAD: raises when Google rejects the code' do
    stub_google_token_exchange(
      status: 400,
      body: { error: 'invalid_grant' }
    )

    _(proc {
      LockedCV::ExchangeGoogleAuthCode.new(app.config).call('google-code')
    }).must_raise LockedCV::ExchangeGoogleAuthCode::TokenExchangeError
  end

  it 'BAD: raises when Google omits the id token' do
    stub_google_token_exchange(
      status: 200,
      body: { access_token: 'ignored-access-token' }
    )

    _(proc {
      LockedCV::ExchangeGoogleAuthCode.new(app.config).call('google-code')
    }).must_raise LockedCV::ExchangeGoogleAuthCode::TokenExchangeError
  end

  def stub_google_token_exchange(status:, body:)
    WebMock.stub_request(:post, app.config.GOOGLE_TOKEN_URL)
           .with do |request|
             form = URI.decode_www_form(request.body).to_h
             form['client_id'] == app.config.GOOGLE_CLIENT_ID &&
               form['client_secret'] == app.config.GOOGLE_CLIENT_SECRET &&
               form['code'] == 'google-code' &&
               form['grant_type'] == 'authorization_code' &&
               form['redirect_uri'] == "#{app.config.APP_URL}/auth/sso/google/callback"
           end
           .to_return(
             status:,
             body: body.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
