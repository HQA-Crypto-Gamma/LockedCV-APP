# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Settings flow' do
  before do
    @account = {
      'id' => 'account-id',
      'username' => 'ada-lovelace',
      'email' => 'ada@example.com',
      'roles' => ['admin'],
      'auth_token' => 'auth-token'
    }
  end

  after do
    WebMock.reset!
  end

  it 'BAD: rejects unknown system roles without calling the API' do
    stub_login
    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'

    post '/settings', username: 'alan-turing', role: 'owner'

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/settings\z}
    assert_not_requested(:put, "#{API_URL}/accounts/alan-turing/system_roles/owner")
  end

  it 'HAPPY: disables role controls for the current account' do
    stub_login
    stub_list_accounts
    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'

    get '/settings'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Current account'
    _(last_response.body).must_include %(aria-label="Role for ada-lovelace" disabled="")
    _(last_response.body).must_include %(<button disabled="" type="submit">Update</button>)
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

  def stub_list_accounts
    accounts = [
      @account.slice('id', 'username', 'email', 'roles'),
      {
        'id' => 'other-account-id',
        'username' => 'alan-turing',
        'email' => 'alan@example.com',
        'roles' => ['member']
      }
    ]

    WebMock.stub_request(:get, "#{API_URL}/accounts")
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: { data: accounts.map { |attributes| { attributes: } } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
