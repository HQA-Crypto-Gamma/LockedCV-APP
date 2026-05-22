# frozen_string_literal: true

require 'roda'
require 'slim'
require 'slim/include'

module LockedCV
  # Base class for the LockedCV Web App
  class App < Roda
    plugin :render, engine: 'slim', views: 'app/presentation/views'
    plugin :assets, css: 'style.css', path: 'app/presentation/assets'
    plugin :multi_route
    plugin :flash

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_session = CurrentSession.new(session)
      @current_account = @current_session.current_account

      routing.redirect_http_to_https if App.environment == :production

      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        attachments = current_account_attachments
        view 'home', locals: { current_account: @current_account, attachments: }
      end
    end

    private

    def current_account_attachments
      return [] if @current_account.logged_out?

      ListAttachments.new(App.config, current_account: @current_account).call
    rescue ListAttachments::ServiceUnavailableError => e
      App.logger.warn "ATTACHMENTS UNAVAILABLE: #{e.inspect}"
      []
    end

    def require_login!(routing)
      return if @current_account.logged_in?

      flash[:error] = 'Please log in to continue'
      routing.redirect '/#login-modal'
    end

    def admin?
      @current_account.admin?
    end
  end
end
