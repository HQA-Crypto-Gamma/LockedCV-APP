# frozen_string_literal: true

require 'roda'
require_relative 'app'

module LockedCV
  # Authentication routes for the LockedCV Web App
  class App < Roda
    route('auth') do |routing|
      routing.is 'login' do
        # GET /auth/login
        routing.get do
          routing.redirect '/'
        end

        # POST /auth/login
        routing.post do
          login_account(routing)
        rescue AuthenticateAccount::UnauthorizedError => e
          App.logger.warn "LOGIN FAILED: #{e.inspect}"
          flash.now[:error] = 'Username and password did not match our records'
          response.status = 403
          view :login, locals: { current_account: @current_account }
        rescue AuthenticateAccount::ServiceUnavailableError => e
          App.logger.error "AUTHENTICATION SERVICE UNAVAILABLE: #{e.inspect}"
          flash.now[:error] = 'Authentication service is temporarily unavailable'
          response.status = 503
          view :login, locals: { current_account: @current_account }
        end
      end

      routing.on 'logout' do
        # GET /auth/logout
        routing.get do
          session[:current_account] = nil
          flash[:notice] = 'You have been logged out'
          routing.redirect '/'
        end
      end
    end

    private

    def login_account(routing)
      account = AuthenticateAccount.new(App.config).call(**credentials_from(routing))

      session[:current_account] = account
      flash[:notice] = "Welcome back #{account['username']}!"
      routing.redirect "/account/#{account['username']}"
    end

    def credentials_from(routing)
      {
        username: routing.params['username'].to_s.strip,
        password: routing.params['password'].to_s
      }
    end
  end
end
