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
        rescue FormValidationError => e
          flash[:error] = e.message
          routing.redirect '/'
        rescue AuthenticateAccount::UnauthorizedError => e
          App.logger.warn "LOGIN FAILED: #{e.inspect}"
          flash[:error] = 'Username and password did not match our records'
          routing.redirect '/'
        rescue AuthenticateAccount::ServiceUnavailableError => e
          App.logger.error "AUTHENTICATION SERVICE UNAVAILABLE: #{e.inspect}"
          flash[:error] = 'Authentication service is temporarily unavailable'
          routing.redirect '/'
        end
      end

      routing.on 'register' do
        @register_route = '/auth/register'

        # GET /auth/register/[registration_token]
        routing.is String do |registration_token|
          routing.get do
            token = RegistrationToken.load(registration_token)
            view :register_confirm,
                 locals: {
                   registration_token: registration_token,
                   email: token.email,
                   username: token.username,
                   current_account: @current_account
                 }
          rescue RegistrationToken::InvalidTokenError
            flash[:error] = 'Verification link is invalid or expired'
            routing.redirect @register_route
          end

          # POST /auth/register/[registration_token]
          routing.post do
            complete_registration(routing, registration_token)
          rescue FormValidationError => e
            flash[:error] = e.message
            routing.redirect "#{@register_route}/#{registration_token}"
          rescue RegistrationToken::InvalidTokenError
            flash[:error] = 'Verification link is invalid or expired'
            routing.redirect @register_route
          rescue RegisterAccount::ValidationError => e
            flash[:error] = e.message
            routing.redirect "#{@register_route}/#{registration_token}"
          rescue RegisterAccount::ServiceUnavailableError => e
            App.logger.error "REGISTRATION SERVICE UNAVAILABLE: #{e.inspect}"
            flash[:error] = 'Registration is temporarily unavailable'
            routing.redirect "#{@register_route}/#{registration_token}"
          rescue StandardError => e
            App.logger.error "ERROR CREATING ACCOUNT: #{e.inspect}"
            flash[:error] = 'Could not create account'
            routing.redirect @register_route
          end
        end

        routing.is do
          # GET /auth/register
          routing.get do
            routing.redirect '/' if @current_account.logged_in?

            view :register, locals: { form_data: {}, current_account: @current_account }
          end

          # POST /auth/register
          routing.post do
            form_data = validate_form(Form::RegistrationStart, routing.params)
            VerifyRegistration.new(App.config).call(
              email: form_data[:email].to_s.strip,
              username: form_data[:username].to_s.strip
            )
            flash[:notice] = 'Check your email for a verification link'
            routing.redirect '/'
          rescue FormValidationError => e
            flash.now[:error] = e.message
            response.status = 400
            view :register, locals: { form_data: e.values.transform_keys(&:to_s), current_account: @current_account }
          rescue VerifyRegistration::VerificationError => e
            flash[:error] = e.message
            routing.redirect @register_route
          rescue VerifyRegistration::ApiServerError => e
            App.logger.warn "API server error: #{e.inspect}"
            flash[:error] = 'Our servers are not responding -- please try later'
            routing.redirect @register_route
          rescue StandardError => e
            App.logger.error "ERROR REGISTERING: #{e.inspect}"
            flash[:error] = 'Could not start registration'
            routing.redirect @register_route
          end
        end
      end

      routing.on 'logout' do
        # GET /auth/logout
        routing.get do
          @current_session.delete
          flash[:notice] = 'You have been logged out'
          routing.redirect '/'
        end
      end
    end
    # rubocop:enable Metrics/BlockLength

    private

    def login_account(routing)
      authenticated = AuthenticateAccount.new(App.config).call(**credentials_from(routing.params))
      account = Account.new(authenticated[:account], authenticated[:auth_token])

      @current_session.current_account = account
      flash[:notice] = "Welcome back #{account.username}!"
      routing.redirect '/'
    end

    def complete_registration(routing, registration_token)
      token = RegistrationToken.load(registration_token)
      form_data = registration_data_from(routing)
      validate_registration_password!(form_data)
      form_data = form_data.merge(
        'email' => token.email,
        'username' => token.username
      )

      account = RegisterAccount.new(App.config).call(registration_payload(form_data))

      flash[:notice] = "Account #{account['username']} created. Please log in."
      routing.redirect '/'
    end

    def credentials_from(params)
      form_data = validate_form(Form::LoginCredentials, params)
      {
        username: form_data[:username].to_s.strip,
        password: form_data[:password].to_s
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

    def validate_registration_password!(form_data)
      validate_form(
        Form::RegistrationPassword,
        password: form_data['password'],
        password_confirmation: form_data['password_confirmation']
      )
    end

    def registration_field_value(params, field)
      value = params[field].to_s
      field.start_with?('password') ? value : value.strip
    end
  end
end
