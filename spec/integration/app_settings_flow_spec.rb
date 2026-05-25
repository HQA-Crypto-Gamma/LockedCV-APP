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
