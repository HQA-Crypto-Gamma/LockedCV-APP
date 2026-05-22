# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Attachment delete route' do
  before do
    @account = {
      'id' => 'account-id',
      'username' => 'ada-lovelace',
      'email' => 'ada@example.com',
      'roles' => ['member'],
      'auth_token' => 'auth-token'
    }
    @attachment_id = 'attachment-id'
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: deletes the selected attachment for the logged-in account' do
    stub_login
    stub_delete

    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'
    post "/attachments/#{@attachment_id}/delete"

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/$}
    assert_requested(:delete, "#{API_URL}/accounts/#{@account['id']}/attachments/#{@attachment_id}")
  end

  private

  def stub_login
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .to_return(
             status: 200,
             body: { data: { attributes: @account } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end

  def stub_delete
    WebMock.stub_request(:delete, "#{API_URL}/accounts/#{@account['id']}/attachments/#{@attachment_id}")
           .with(headers: { 'Authorization' => "Bearer #{@account['auth_token']}" })
           .to_return(
             status: 200,
             body: { message: 'Attachment deleted' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
