# frozen_string_literal: true

require_relative '../spec_helper'

describe 'GetAccountApiKey service' do
  before do
    @current_account = current_account
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: returns read-only API key for the current account' do
    WebMock.stub_request(:get, "#{API_URL}/accounts/ada-lovelace")
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: account_detail_response('read-only-api-key').to_json,
             headers: { 'content-type' => 'application/json' }
           )

    api_key = LockedCV::GetAccountApiKey.new(app.config, current_account: @current_account).call

    _(api_key).must_equal 'read-only-api-key'
  end

  it 'BAD: raises NotFoundError when API hides the account' do
    WebMock.stub_request(:get, "#{API_URL}/accounts/ada-lovelace")
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 404,
             body: { message: 'Account not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::GetAccountApiKey.new(app.config, current_account: @current_account).call
    }).must_raise LockedCV::GetAccountApiKey::NotFoundError
  end

  it 'BAD: raises ServiceUnavailableError when API response is malformed' do
    WebMock.stub_request(:get, "#{API_URL}/accounts/ada-lovelace")
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: { data: {} }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::GetAccountApiKey.new(app.config, current_account: @current_account).call
    }).must_raise LockedCV::GetAccountApiKey::ServiceUnavailableError
  end

  def account_detail_response(api_key)
    {
      data: {
        type: 'authorized_account',
        attributes: {
          account: {
            data: {
              type: 'account',
              attributes: {
                id: 'account-id',
                username: 'ada-lovelace',
                email: 'ada@example.com'
              }
            }
          },
          auth_token: api_key
        }
      }
    }
  end
end
