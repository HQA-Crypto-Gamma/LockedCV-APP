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
        accounts = ListAccounts.new(App.config, current_account: @current_account).call

        view :settings, locals: { accounts: }
      rescue ListAccounts::UnauthorizedError => e
        App.logger.warn "SETTINGS UNAUTHORIZED: #{e.inspect}"
        flash[:error] = 'Only admins can view settings'
        routing.redirect "/account/#{@current_account.username}"
      rescue ListAccounts::ServiceUnavailableError => e
        App.logger.error "SETTINGS SERVICE UNAVAILABLE: #{e.inspect}"
        flash.now[:error] = 'Settings are temporarily unavailable'
        response.status = 503
        view :settings, locals: { accounts: [] }
      end

      routing.on 'accounts', String, 'delete' do |account_id|
        routing.post do
          DeleteAccount.new(App.config, current_account: @current_account).call(target_account_id: account_id)

          flash[:notice] = 'Account deleted'
          routing.redirect '/settings'
        rescue DeleteAccount::UnauthorizedError => e
          App.logger.warn "ACCOUNT DELETE UNAUTHORIZED: #{e.inspect}"
          flash[:error] = e.message.empty? ? 'Only admins can delete accounts' : e.message
          routing.redirect '/settings'
        rescue DeleteAccount::ValidationError => e
          App.logger.warn "ACCOUNT DELETE INVALID: #{e.inspect}"
          flash[:error] = e.message
          routing.redirect '/settings'
        rescue DeleteAccount::ServiceUnavailableError => e
          App.logger.error "ACCOUNT DELETE SERVICE UNAVAILABLE: #{e.inspect}"
          flash[:error] = 'Account delete is temporarily unavailable'
          routing.redirect '/settings'
        end
      end

      routing.post do
        form_data = validate_form(Form::AssignSystemRole, routing.params)
        AssignSystemRole.new(App.config, current_account: @current_account).call(
          target_username: form_data[:username].to_s.strip,
          role_name: form_data[:role].to_s
        )

        flash[:notice] = 'Role updated'
        routing.redirect '/settings'
      rescue FormValidationError => e
        App.logger.warn "ROLE UPDATE INVALID: #{e.inspect}"
        flash[:error] = e.message
        routing.redirect '/settings'
      rescue AssignSystemRole::UnauthorizedError => e
        App.logger.warn "ROLE UPDATE UNAUTHORIZED: #{e.inspect}"
        flash[:error] = e.message.empty? ? 'Only admins can update roles' : e.message
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
      routing.redirect "/account/#{@current_account.username}"
    end
  end
end
