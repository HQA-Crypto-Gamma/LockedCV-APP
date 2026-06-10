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

  it 'HAPPY: shows a Google sign-in link' do
    get '/'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'href="/auth/sso/google"'
  end

  it 'HAPPY: redirects to Google authorization with state' do
    get '/auth/sso/google'

    _(last_response.status).must_equal 302
    uri = URI.parse(last_response.location)
    query = URI.decode_www_form(uri.query).to_h

    _(last_response.location).must_match(%r{\Ahttps://accounts\.google\.com/o/oauth2/v2/auth})
    _(query['client_id']).must_equal app.config.GOOGLE_CLIENT_ID
    _(query['redirect_uri']).must_equal "#{app.config.APP_URL}/auth/sso/google/callback"
    _(query['response_type']).must_equal 'code'
    _(query['scope']).must_equal 'openid email profile'
    _(query['state']).wont_be_empty
  end

  it 'HAPPY: signs in with matching Google callback state' do
    get '/auth/sso/google'
    state = URI.decode_www_form(URI.parse(last_response.location).query).to_h.fetch('state')
    stub_google_token_exchange
    stub_google_jwks
    stub_api_sso
    stub_current_account_attachments

    get '/auth/sso/google/callback', state:, code: 'google-code'

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}
    follow_redirect!
    _(last_response.body).must_include 'Welcome back google-user!'
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
           .with { |request| google_token_request_valid?(request) }
           .to_return(
             status: 200,
             body: { id_token: 'google-id-token' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end

  def google_token_request_valid?(request)
    form = URI.decode_www_form(request.body).to_h
    form['client_id'] == app.config.GOOGLE_CLIENT_ID &&
      form['client_secret'] == app.config.GOOGLE_CLIENT_SECRET &&
      form['code'] == 'google-code' &&
      form['grant_type'] == 'authorization_code' &&
      form['redirect_uri'] == "#{app.config.APP_URL}/auth/sso/google/callback"
  end

  def stub_google_jwks
    WebMock.stub_request(:get, app.config.GOOGLE_JWKS_URL)
           .to_return(
             status: 200,
             body: { keys: [{ kid: 'google-key' }] }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end

  def stub_api_sso
    WebMock.stub_request(:post, "#{API_URL}/auth/sso")
           .with { |request| signed_data(request) == JSON.parse(api_sso_request.to_json) }
           .to_return(
             status: 200,
             body: api_sso_response.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end

  def api_sso_request
    {
      provider: 'google',
      id_token: 'google-id-token',
      jwks: { keys: [{ kid: 'google-key' }] }
    }
  end

  def api_sso_response
    {
      data: {
        type: 'authenticated_account',
        attributes: api_sso_account_attributes
      }
    }
  end

  def api_sso_account_attributes
    {
      id: 'account-id',
      username: 'google-user',
      email: 'google-user@example.com',
      roles: ['member'],
      auth_token: 'session-token'
    }
  end

  def stub_current_account_attachments
    WebMock.stub_request(:get, "#{API_URL}/attachments")
           .with(headers: { 'Authorization' => 'Bearer session-token' })
           .to_return(
             status: 200,
             body: { data: [] }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
