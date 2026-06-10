# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Registration flow' do
  before do
    @registration = {
      username: 'grace-hopper',
      email: 'grace@example.com'
    }
  end

  after do
    WebMock.reset!
  end

  def registration_token
    LockedCV::RegistrationToken.new(**@registration).to_s
  end

  def stub_available_registration
    WebMock.stub_request(:post, "#{API_URL}/accounts/registration/check")
           .with { |request| signed_data(request) == @registration.transform_keys(&:to_s) }
           .to_return(
             status: 200,
             body: { available: true }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end

  def stub_verification_email(status: 202, message: 'Verification email sent')
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .with { |request| verification_email_request?(request) }
           .to_return(
             status: status,
             body: { message: message }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end

  def stub_account_creation(expected_payload)
    WebMock.stub_request(:post, "#{API_URL}/accounts")
           .with { |request| signed_data(request) == expected_payload.transform_keys(&:to_s) }
           .to_return(status: 201, body: account_creation_response.to_json, headers: json_headers)
  end

  def verification_email_request?(request)
    body = JSON.parse(request.body)
    data = body.fetch('data')
    body['signature'].to_s != '' &&
      data['username'] == @registration[:username] &&
      data['email'] == @registration[:email] &&
      data['verification_url'].start_with?("#{app.config.APP_URL}/auth/register/")
  end

  def account_creation_response
    {
      data: {
        data: {
          attributes: account_creation_attributes
        }
      }
    }
  end

  def account_creation_attributes
    {
      id: 'account-id',
      username: @registration[:username],
      email: @registration[:email],
      roles: ['member']
    }
  end

  def json_headers
    { 'content-type' => 'application/json' }
  end

  it 'HAPPY: renders the registration request page for logged-out visitors' do
    get '/auth/register'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Create an account'
    _(last_response.body).must_include 'name="username"'
    _(last_response.body).must_include 'name="email"'
    _(last_response.body).must_include 'Send verification email'
  end

  it 'HAPPY: starts registration and asks the visitor to check email' do
    stub_available_registration
    stub_verification_email

    post '/auth/register', @registration

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}

    follow_redirect!
    _(last_response.body).must_include 'Check your email for a verification link'
  end

  it 'BAD: rejects invalid registration start input without calling the API' do
    post '/auth/register', username: 'abc', email: 'not-an-email'

    _(last_response.status).must_equal 400
    _(last_response.body).must_include 'must be 4-40 ASCII letters'
    _(last_response.body).must_include %(value="abc")
    _(last_response.body).must_include %(value="not-an-email")
    assert_not_requested(:post, "#{API_URL}/accounts/registration/check")
    assert_not_requested(:post, "#{API_URL}/auth/register")
  end

  it 'HAPPY: renders registration confirmation page from a valid token' do
    token = registration_token

    get "/auth/register/#{token}"

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Finish registration'
    _(last_response.body).must_include %(name="username")
    _(last_response.body).must_include %(value="#{@registration[:username]}")
    _(last_response.body).must_include %(name="email")
    _(last_response.body).must_include %(value="#{@registration[:email]}")
    _(last_response.body).must_include 'readonly'
  end

  it 'HAPPY: completes registration from a valid token' do
    token = registration_token
    expected_payload = {
      username: @registration[:username],
      email: @registration[:email],
      phone_number: nil,
      first_name: 'Grace',
      last_name: 'Hopper',
      birthday: nil,
      address: nil,
      identification_numbers: nil,
      password: '@3Fs^1HfaF$2'
    }
    stub_account_creation(expected_payload)

    post "/auth/register/#{token}", {
      first_name: 'Grace',
      last_name: 'Hopper',
      password: '@3Fs^1HfaF$2',
      password_confirmation: '@3Fs^1HfaF$2'
    }

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}

    follow_redirect!
    _(last_response.body).must_include 'Account grace-hopper created. Please log in.'
  end

  it 'BAD: rejects mismatched registration passwords without creating an account' do
    token = registration_token

    post "/auth/register/#{token}", {
      password: '@3Fs^1HfaF$2',
      password_confirmation: 'different-secret'
    }

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/auth/register/}
    assert_not_requested(:post, "#{API_URL}/accounts")
  end

  it 'BAD: rejects tampered registration tokens without creating an account' do
    post '/auth/register/not-a-real-token', {
      password: 'grace-secret',
      password_confirmation: 'grace-secret'
    }

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/auth/register\z}
    assert_not_requested(:post, "#{API_URL}/accounts")
  end
end
