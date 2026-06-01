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

    get '/auth/sso/google/callback', state:, code: 'google-code'

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}
    follow_redirect!
    _(last_response.body).must_include 'Google sign-in callback verified'
  end

  it 'BAD: rejects mismatched Google callback state' do
    get '/auth/sso/google'

    get '/auth/sso/google/callback', state: 'wrong-state', code: 'google-code'

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}
    follow_redirect!
    _(last_response.body).must_include 'Sign-in session expired or could not be verified'
  end
end
