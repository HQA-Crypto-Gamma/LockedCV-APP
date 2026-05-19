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
           .with { |request| JSON.parse(request.body) == @registration.transform_keys(&:to_s) }
           .to_return(
             status: 200,
             body: { available: true }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .with do |request|
             body = JSON.parse(request.body)
             body['username'] == @registration[:username] &&
               body['email'] == @registration[:email] &&
               body['verification_url'].start_with?("#{app.config.APP_URL}/auth/register/")
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
  end

  it 'BAD: raises verification error when availability check fails' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/registration/check")
           .with { |request| JSON.parse(request.body) == @registration.transform_keys(&:to_s) }
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
end
