# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Account flow' do
  before do
    @account = {
      'id' => 'account-id',
      'username' => 'ada-lovelace',
      'email' => 'ada@example.com',
      'roles' => ['member'],
      'auth_token' => 'auth-token'
    }
  end

  after do
    WebMock.reset!
  end

  it 'BAD: rejects invalid profile input without calling the API' do
    stub_login
    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'

    post '/account/ada-lovelace', email: 'not-an-email', birthday: '1815-12-10'

    _(last_response.status).must_equal 400
    _(last_response.body).must_include 'must be a valid email address'
    assert_not_requested(:put, "#{API_URL}/account")
  end

  it 'BAD: rejects invalid profile birthdays without calling the API' do
    stub_login
    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'

    post '/account/ada-lovelace', email: 'ada@example.com', birthday: 'not-a-date'

    _(last_response.status).must_equal 400
    _(last_response.body).must_include 'must use YYYY-MM-DD format'
    assert_not_requested(:put, "#{API_URL}/account")
  end

  it 'BAD: rejects invalid password input without calling the API' do
    stub_login
    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'

    post '/account/ada-lovelace/password',
         current_password: 'old-secret',
         password: '@3Fs^1HfaF$2',
         password_confirmation: 'different-secret'

    _(last_response.status).must_equal 400
    _(last_response.body).must_include 'does not match password'
    assert_not_requested(:put, "#{API_URL}/account/password")
  end

  it 'BAD: rejects blank password input without calling the API' do
    stub_login
    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'

    post '/account/ada-lovelace/password',
         current_password: '',
         password: '',
         password_confirmation: ''

    _(last_response.status).must_equal 400
    _(last_response.body).must_include 'must be filled'
    assert_not_requested(:put, "#{API_URL}/account/password")
  end

  private

  def stub_login
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .to_return(
             status: 200,
             body: { data: { type: 'authenticated_account', attributes: @account } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
