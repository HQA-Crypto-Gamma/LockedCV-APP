# frozen_string_literal: true

require 'uri'
require_relative '../spec_helper'

describe 'Authentication flow' do
  after do
    WebMock.reset!
  end

  it 'BAD: rejects blank login form without calling the API' do
    post '/auth/login', username: '', password: ''

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}
    assert_not_requested(:post, "#{API_URL}/auth/authenticate")
  end

  it 'HAPPY: redirects to Google authorization with state' do
    get '/auth/sso/google'

    _(last_response.status).must_equal 302
    uri = URI.parse(last_response.location)
    query = URI.decode_www_form(uri.query).to_h

    _(last_response.location).must_match(%r{\Ahttps://accounts\.google\.com/o/oauth2/v2/auth})
    _(query['client_id']).must_equal 'test-google-client-id'
    _(query['redirect_uri']).must_equal "#{app.config.APP_URL}/auth/sso/google/callback"
    _(query['response_type']).must_equal 'code'
    _(query['scope']).must_equal 'openid email profile'
    _(query['state']).wont_be_empty
  end

  it 'HAPPY: accepts matching Google callback state' do
    get '/auth/sso/google'
    state = URI.decode_www_form(URI.parse(last_response.location).query).to_h.fetch('state')
    stub_google_token_exchange

    get '/auth/sso/google/callback', state:, code: 'google-code'

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}
    follow_redirect!
    _(last_response.body).must_include 'Google id token received'
  end

  it 'BAD: rejects mismatched Google callback state' do
    get '/auth/sso/google'

    get '/auth/sso/google/callback', state: 'wrong-state', code: 'google-code'

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}
    follow_redirect!
    _(last_response.body).must_include 'Sign-in session expired or could not be verified'
  end

  it 'BAD: reports Google token exchange failures' do
    get '/auth/sso/google'
    state = URI.decode_www_form(URI.parse(last_response.location).query).to_h.fetch('state')
    WebMock.stub_request(:post, app.config.GOOGLE_TOKEN_URL)
           .to_return(
             status: 400,
             body: { error: 'invalid_grant' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    get '/auth/sso/google/callback', state:, code: 'google-code'

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}
    follow_redirect!
    _(last_response.body).must_include 'Could not sign in with Google'
  end

  def stub_google_token_exchange
    WebMock.stub_request(:post, app.config.GOOGLE_TOKEN_URL)
           .with do |request|
             form = URI.decode_www_form(request.body).to_h
             form['client_id'] == 'test-google-client-id' &&
               form['client_secret'] == 'test-google-client-secret' &&
               form['code'] == 'google-code' &&
               form['grant_type'] == 'authorization_code' &&
               form['redirect_uri'] == "#{app.config.APP_URL}/auth/sso/google/callback"
           end
           .to_return(
             status: 200,
             body: { id_token: 'google-id-token' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
