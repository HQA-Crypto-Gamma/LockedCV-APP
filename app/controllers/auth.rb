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
          view :login, locals: { current_account: @current_account }
        end
      end
    end
  end
end
