# frozen_string_literal: true

require 'roda'
require_relative 'app'

module LockedCV
  # Admin settings routes for the LockedCV Web App
  class App < Roda
    # rubocop:disable Metrics/BlockLength
    route('settings') do |routing|
      require_login!(routing)
      require_admin!(routing)

      routing.get do
        accounts = ListAccounts.new(App.config).call(
          current_account_id: @current_account['id']
        )

        view :settings, locals: { accounts: }
      rescue ListAccounts::UnauthorizedError => e
        App.logger.warn "SETTINGS UNAUTHORIZED: #{e.inspect}"
        flash[:error] = 'Only admins can view settings'
        routing.redirect "/account/#{@current_account['username']}"
      rescue ListAccounts::ServiceUnavailableError => e
        App.logger.error "SETTINGS SERVICE UNAVAILABLE: #{e.inspect}"
        flash.now[:error] = 'Settings are temporarily unavailable'
        response.status = 503
        view :settings, locals: { accounts: [] }
      end

      routing.post do
        AssignSystemRole.new(App.config).call(
          current_account_id: @current_account['id'],
          target_username: routing.params['username'].to_s,
          role_name: routing.params['role'].to_s
        )

        flash[:notice] = 'Role updated'
        routing.redirect '/settings'
      rescue AssignSystemRole::UnauthorizedError => e
        App.logger.warn "ROLE UPDATE UNAUTHORIZED: #{e.inspect}"
        flash[:error] = 'Only admins can update roles'
        routing.redirect '/settings'
      rescue AssignSystemRole::ValidationError => e
        App.logger.warn "ROLE UPDATE INVALID: #{e.inspect}"
        flash[:error] = e.message
        routing.redirect '/settings'
      rescue AssignSystemRole::ServiceUnavailableError => e
        App.logger.error "ROLE UPDATE SERVICE UNAVAILABLE: #{e.inspect}"
        flash[:error] = 'Role update is temporarily unavailable'
        routing.redirect '/settings'
      end
    end
    # rubocop:enable Metrics/BlockLength

    private

    def require_admin!(routing)
      return if admin?

      flash[:error] = 'Only admins can view settings'
      routing.redirect "/account/#{@current_account['username']}"
    end
  end
end
