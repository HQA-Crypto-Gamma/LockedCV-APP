# frozen_string_literal: true

require 'figaro'
require 'logger'
require 'openssl'
require 'rack/session'
require 'rack/session/redis'
require 'roda'
require_relative '../require_app'

require_app('lib')

module LockedCV
  # Configuration for the LockedCV Web App
  class App < Roda
    plugin :environments

    Figaro.application = Figaro::Application.new(
      environment: environment,
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load
    def self.config = Figaro.env

    configure :development, :production do
      plugin :common_logger, $stdout
    end

    configure :production do
      plugin :redirect_http_to_https
      plugin :hsts
    end

    LOGGER = Logger.new($stderr)
    def self.logger = LOGGER

    SecureMessage.setup(ENV.delete('MSG_KEY'))
    SignedMessage.setup(ENV.delete('SIGNING_KEY'))

    require 'pry'

    ONE_MONTH = 30 * 24 * 60 * 60
    @redis_url = ENV.delete('REDISCLOUD_URL') || ENV.delete('REDIS_URL')
    @redis_server =
      if @redis_url&.start_with?('rediss://')
        { url: @redis_url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
      else
        @redis_url
      end

    SecureSession.setup(@redis_server)
    SESSION_COOKIE_OPTIONS = {
      expire_after: ONE_MONTH,
      httponly: true,
      same_site: :lax
    }.freeze

    configure :development, :test do
      use Rack::Session::Pool,
          **SESSION_COOKIE_OPTIONS
    end

    configure :production do
      use Rack::Session::Redis,
          **SESSION_COOKIE_OPTIONS,
          secure: true,
          redis_server: @redis_server
    end

    configure :development, :test do
      logger.level = Logger::ERROR
    end
  end
end
