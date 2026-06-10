# frozen_string_literal: true

require 'uri'
require_relative '../spec_helper'

describe 'GoogleSsoConfig service' do
  it 'HAPPY: builds the Google authorization URL' do
    google = LockedCV::GoogleSsoConfig.new(app.config)

    uri = URI.parse(google.authorization_url('state-token'))
    query = URI.decode_www_form(uri.query).to_h

    _(uri.to_s).must_match(%r{\Ahttps://accounts\.google\.com/o/oauth2/v2/auth})
    _(query['client_id']).must_equal app.config.GOOGLE_CLIENT_ID
    _(query['redirect_uri']).must_equal "#{app.config.APP_URL}/auth/sso/google/callback"
    _(query['response_type']).must_equal 'code'
    _(query['scope']).must_equal LockedCV::GoogleSsoConfig::SCOPE
    _(query['state']).must_equal 'state-token'
  end
end
