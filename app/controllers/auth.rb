# frozen_string_literal: true

require 'roda'
require_relative 'app'

module LockedCV
  # Authentication routes for the LockedCV Web App
  class App < Roda
    REGISTRATION_FIELDS = %w[
      username email phone_number first_name last_name birthday address
      identification_numbers password password_confirmation
    ].freeze
    API_REGISTRATION_FIELDS = REGISTRATION_FIELDS - %w[password_confirmation]

    # rubocop:disable Metrics/BlockLength
    route('auth') do |routing|
      routing.is 'login' do
        # GET /auth/login
        routing.get do
          routing.redirect '/#login-modal'
        end

        # POST /auth/login
        routing.post do
          login_account(routing)
        rescue AuthenticateAccount::UnauthorizedError => e
          App.logger.warn "LOGIN FAILED: #{e.inspect}"
          flash[:error] = 'Username and password did not match our records'
          routing.redirect '/#login-modal'
        rescue AuthenticateAccount::ServiceUnavailableError => e
          App.logger.error "AUTHENTICATION SERVICE UNAVAILABLE: #{e.inspect}"
          flash[:error] = 'Authentication service is temporarily unavailable'
          routing.redirect '/#login-modal'
        end
      end

      routing.is 'register' do
        # GET /auth/register
        routing.get do
          routing.redirect '/' if @current_account

          view :register, locals: { form_data: {}, current_account: @current_account }
        end

        # POST /auth/register
        routing.post do
          register_account(routing)
        rescue RegisterAccount::ValidationError => e
          App.logger.warn "REGISTRATION VALIDATION FAILED: #{e.inspect}"
          flash.now[:error] = e.message
          response.status = 400
          view :register, locals: { form_data: registration_data_from(routing), current_account: @current_account }
        rescue RegisterAccount::ServiceUnavailableError => e
          App.logger.error "REGISTRATION SERVICE UNAVAILABLE: #{e.inspect}"
          flash.now[:error] = 'Registration is temporarily unavailable'
          response.status = 503
          view :register, locals: { form_data: registration_data_from(routing), current_account: @current_account }
        end
      end

      routing.on 'logout' do
        # GET /auth/logout
        routing.get do
          SecureSession.new(session).delete(:current_account)
          flash[:notice] = 'You have been logged out'
          routing.redirect '/'
        end
      end
    end
    # rubocop:enable Metrics/BlockLength

    private

    def login_account(routing)
      account = AuthenticateAccount.new(App.config).call(**credentials_from(routing))

      SecureSession.new(session).set(:current_account, account)
      flash[:notice] = "Welcome back #{account['username']}!"
      routing.redirect '/'
    end

    def register_account(routing)
      form_data = registration_data_from(routing)
      ensure_password_confirmation!(form_data)
      account = RegisterAccount.new(App.config).call(registration_payload(form_data))

      flash[:notice] = "Account #{account['username']} created. Please log in."
      routing.redirect '/#login-modal'
    end

    def credentials_from(routing)
      {
        username: routing.params['username'].to_s.strip,
        password: routing.params['password'].to_s
      }
    end

    def registration_data_from(routing)
      REGISTRATION_FIELDS.to_h do |field|
        [field, registration_field_value(routing.params, field)]
      end
    end

    def registration_payload(form_data)
      API_REGISTRATION_FIELDS.to_h { |field| [field.to_sym, form_data[field]] }
    end

    def ensure_password_confirmation!(form_data)
      return if form_data['password'] == form_data['password_confirmation']

      raise RegisterAccount::ValidationError, 'Password confirmation does not match'
    end

    def registration_field_value(params, field)
      value = params[field].to_s
      field.start_with?('password') ? value : value.strip
    end
  end
end
