# frozen_string_literal: true

require 'roda'
require_relative 'app'

module LockedCV
  # Account routes for the LockedCV Web App
  class App < Roda
    route('account') do |routing|
      require_login!(routing)

      routing.on String do |username|
        routing.on 'edit' do
          routing.get { render_profile(routing, username, editing: true) }
        end

        # GET /account/[username]
        routing.get do
          render_profile(routing, username)
        end

        # POST /account/[username]
        routing.post do
          update_profile(routing, username)
        end
      end
    end

    private

    def render_profile(routing, username, editing: false)
      ensure_own_profile!(routing, username)

      view :account, locals: { account: current_account_profile, editing: }
    rescue FindAccount::NotFoundError
      flash[:error] = 'Account not found'
      routing.redirect '/'
    rescue FindAccount::ServiceUnavailableError => e
      App.logger.error "ACCOUNT FETCH UNAVAILABLE: #{e.inspect}"
      flash.now[:error] = 'Profile is temporarily unavailable'
      view :account, locals: { account: @current_account, editing: false }
    end

    def update_profile(routing, username)
      ensure_own_profile!(routing, username)
      store_current_account(updated_profile_account(routing))
      flash[:notice] = 'Profile updated'
      routing.redirect "/account/#{username}"
    rescue UpdateAccount::ValidationError => e
      profile_update_failed(routing, e.message, 400)
    rescue UpdateAccount::ServiceUnavailableError => e
      App.logger.error "ACCOUNT UPDATE UNAVAILABLE: #{e.inspect}"
      profile_update_failed(routing, 'Profile update is temporarily unavailable', 503)
    end

    def updated_profile_account(routing)
      UpdateAccount.new(App.config).call(
        account_id: @current_account['id'],
        profile_data: profile_data_from(routing)
      )
    end

    def store_current_account(updated_account)
      session[:current_account] = updated_account.merge('roles' => Array(@current_account['roles']))
    end

    def ensure_own_profile!(routing, username)
      return if @current_account['username'] == username

      routing.redirect "/account/#{@current_account['username']}"
    end

    def profile_update_failed(routing, message, status)
      flash.now[:error] = message
      response.status = status
      view :account, locals: { account: profile_form_data(routing), editing: true }
    end

    def profile_data_from(routing)
      UpdateAccount::EDITABLE_FIELDS.to_h do |field|
        [field, routing.params[field.to_s].to_s.strip]
      end
    end

    def profile_form_data(routing)
      @current_account.merge(
        profile_data_from(routing).transform_keys(&:to_s)
      )
    end

    def current_account_profile
      profile = FindAccount.new(App.config).call(account_id: @current_account['id'])
      profile.merge('roles' => Array(@current_account['roles']))
    end
  end
end
