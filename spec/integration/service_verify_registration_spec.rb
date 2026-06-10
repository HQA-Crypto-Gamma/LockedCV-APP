# frozen_string_literal: true

require_relative '../spec_helper'

describe 'VerifyRegistration service' do
  before do
    @registration = {
      username: 'grace-hopper',
      email: 'grace@example.com'
    }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: checks availability, then requests verification email' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/registration/check")
           .with { |request| signed_data(request) == @registration.transform_keys(&:to_s) }
           .to_return(
             status: 200,
             body: { available: true }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .with do |request|
             body = JSON.parse(request.body)
             data = body.fetch('data')
             body['signature'].to_s != '' &&
               data['username'] == @registration[:username] &&
               data['email'] == @registration[:email] &&
               data['verification_url'].start_with?("#{app.config.APP_URL}/auth/register/")
           end
           .to_return(
             status: 202,
             body: { message: 'Verification email sent' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    result = LockedCV::VerifyRegistration.new(app.config).call(**@registration)

    _(result[:username]).must_equal @registration[:username]
    _(result[:email]).must_equal @registration[:email]
    _(result[:verification_url]).must_match %r{\A#{Regexp.escape(app.config.APP_URL)}/auth/register/}

    registration_token = result[:verification_url].split('/').last
    loaded_token = LockedCV::RegistrationToken.load(registration_token)
    _(loaded_token.email).must_equal @registration[:email]
    _(loaded_token.username).must_equal @registration[:username]
  end

  it 'BAD: raises verification error when availability check fails' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/registration/check")
           .with { |request| signed_data(request) == @registration.transform_keys(&:to_s) }
           .to_return(
             status: 400,
             body: { message: 'Username already taken' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    error = _(proc {
      LockedCV::VerifyRegistration.new(app.config).call(**@registration)
    }).must_raise LockedCV::VerifyRegistration::VerificationError

    _(error.message).must_equal 'Username already taken'
    assert_not_requested(:post, "#{API_URL}/auth/register")
  end

  it 'BAD: raises verification error when verification email request is invalid' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/registration/check")
           .with { |request| signed_data(request) == @registration.transform_keys(&:to_s) }
           .to_return(
             status: 200,
             body: { available: true }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .to_return(
             status: 400,
             body: { message: 'Email already registered' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    error = _(proc {
      LockedCV::VerifyRegistration.new(app.config).call(**@registration)
    }).must_raise LockedCV::VerifyRegistration::VerificationError

    _(error.message).must_equal 'Email already registered'
  end

  it 'BAD: raises API server error when availability check fails on the server' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/registration/check")
           .with { |request| signed_data(request) == @registration.transform_keys(&:to_s) }
           .to_return(
             status: 500,
             body: { message: 'Unknown server error' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    error = _(proc {
      LockedCV::VerifyRegistration.new(app.config).call(**@registration)
    }).must_raise LockedCV::VerifyRegistration::ApiServerError

    _(error.message).must_equal 'Unknown server error'
    assert_not_requested(:post, "#{API_URL}/auth/register")
  end

  it 'BAD: raises API server error when verification email request fails on the server' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/registration/check")
           .with { |request| signed_data(request) == @registration.transform_keys(&:to_s) }
           .to_return(
             status: 200,
             body: { available: true }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .to_return(
             status: 500,
             body: { message: 'Could not send verification email' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    error = _(proc {
      LockedCV::VerifyRegistration.new(app.config).call(**@registration)
    }).must_raise LockedCV::VerifyRegistration::ApiServerError

    _(error.message).must_equal 'Could not send verification email'
  end
end
