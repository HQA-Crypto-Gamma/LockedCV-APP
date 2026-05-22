# frozen_string_literal: true

require_relative '../spec_helper'

describe 'DeleteAccount service' do
  before do
    @current_account = current_account
    @target_account_id = 'target-id'
    @path = "#{API_URL}/accounts/#{@target_account_id}"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: deletes an account' do
    WebMock.stub_request(:delete, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: { message: 'Account deleted' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    response = LockedCV::DeleteAccount.new(app.config, current_account: @current_account)
                                      .call(target_account_id: @target_account_id)

    _(response).must_equal('message' => 'Account deleted')
  end

  it 'BAD: raises UnauthorizedError when caller is not admin' do
    WebMock.stub_request(:delete, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 403,
             body: { message: 'Only admins can delete accounts' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::DeleteAccount.new(app.config, current_account: @current_account)
                             .call(target_account_id: @target_account_id)
    }).must_raise LockedCV::DeleteAccount::UnauthorizedError
  end

  it 'BAD: raises ValidationError for missing account' do
    WebMock.stub_request(:delete, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 404,
             body: { message: 'Account not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::DeleteAccount.new(app.config, current_account: @current_account)
                             .call(target_account_id: @target_account_id)
    }).must_raise LockedCV::DeleteAccount::ValidationError
  end

  it 'BAD: raises ServiceUnavailableError when API fails' do
    WebMock.stub_request(:delete, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 500,
             body: { message: 'boom' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::DeleteAccount.new(app.config, current_account: @current_account)
                             .call(target_account_id: @target_account_id)
    }).must_raise LockedCV::DeleteAccount::ServiceUnavailableError
  end
end
