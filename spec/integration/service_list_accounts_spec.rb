# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ListAccounts service' do
  before do
    @current_account_id = 'admin-id'
    @accounts = [
      { 'username' => 'ada-lovelace', 'roles' => ['admin'] },
      { 'username' => 'alan-turing', 'roles' => ['member'] }
    ]
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: returns account attributes for admin' do
    WebMock.stub_request(:get, "#{API_URL}/accounts")
           .with(query: { current_account_id: @current_account_id })
           .to_return(
             status: 200,
             body: { data: @accounts.map { |attributes| { attributes: } } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    accounts = LockedCV::ListAccounts.new(app.config).call(
      current_account_id: @current_account_id
    )

    _(accounts).must_equal @accounts
  end

  it 'BAD: raises UnauthorizedError when API rejects current account' do
    WebMock.stub_request(:get, "#{API_URL}/accounts")
           .with(query: { current_account_id: @current_account_id })
           .to_return(
             status: 403,
             body: { message: 'Only admins can list accounts' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::ListAccounts.new(app.config).call(current_account_id: @current_account_id)
    }).must_raise LockedCV::ListAccounts::UnauthorizedError
  end

  it 'BAD: raises ServiceUnavailableError when API fails' do
    WebMock.stub_request(:get, "#{API_URL}/accounts")
           .with(query: { current_account_id: @current_account_id })
           .to_return(
             status: 500,
             body: { message: 'boom' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::ListAccounts.new(app.config).call(current_account_id: @current_account_id)
    }).must_raise LockedCV::ListAccounts::ServiceUnavailableError
  end
end
