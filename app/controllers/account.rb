# frozen_string_literal: true

require 'roda'
require_relative 'app'

module LockedCV
  # Account routes for the LockedCV Web App
  class App < Roda
    route('account') do |routing|
      require_login!(routing)

      routing.on String do |username|
        # GET /account/[username]
        routing.get do
          routing.redirect "/account/#{@current_account['username']}" unless @current_account['username'] == username

          view :account, locals: { account: @current_account }
        end
      end
    end
  end
end
