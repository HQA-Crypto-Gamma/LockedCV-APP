# frozen_string_literal: true

require 'figaro'
require 'logger'
require 'rack/session'
require 'roda'

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

    LOGGER = Logger.new($stderr)
    def self.logger = LOGGER

    require 'pry'

    ONE_MONTH = 30 * 24 * 60 * 60
    use Rack::Session::Cookie,
        expire_after: ONE_MONTH,
        secret: config.SESSION_SECRET

    configure :development, :test do
      logger.level = Logger::ERROR
    end
  end
end
