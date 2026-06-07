# frozen_string_literal: true

require 'uri'

module LockedCV
  # Centralizes Google OAuth/OIDC endpoints and request parameters.
  class GoogleSsoConfig
    AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth'
    TOKEN_URL = 'https://oauth2.googleapis.com/token'
    JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs'
    SCOPE = 'openid email profile'

    def initialize(config)
      @config = config
    end

    def authorization_url(state)
      "#{auth_url}?#{authorization_query(state)}"
    end

    def auth_url
      config.GOOGLE_AUTH_URL || AUTH_URL
    end

    def token_url
      config.GOOGLE_TOKEN_URL || TOKEN_URL
    end

    def jwks_url
      config.GOOGLE_JWKS_URL || JWKS_URL
    end

    def client_id
      config.GOOGLE_CLIENT_ID || test_value('test-google-client-id')
    end

    def client_secret
      config.GOOGLE_CLIENT_SECRET || test_value('test-google-client-secret')
    end

    def redirect_uri
      "#{config.APP_URL}/auth/sso/google/callback"
    end

    private

    attr_reader :config

    def authorization_query(state)
      URI.encode_www_form(
        client_id:,
        redirect_uri:,
        response_type: 'code',
        scope: SCOPE,
        state:
      )
    end

    def test_value(value)
      value if App.environment == :test
    end
  end
end
