# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Attachment scan route' do
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

  it 'HAPPY: renders the masked preview and detected fields for a logged-in account' do
    stub_login
    stub_scan

    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'
    get "/attachments/#{@attachment_id}/scan"

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Mask Review'
    _(last_response.body).must_include 'Ada [EMAIL] [PHONE_NUMBER]'
    _(last_response.body).must_include 'Email'
    _(last_response.body).must_include 'ada@example.com'
    _(last_response.body).must_include 'type="checkbox"'
    assert_requested(:get, "#{API_URL}/attachments/#{@attachment_id}/masked_text")
  end

  it 'SECURITY: redirects guests to the login modal without calling the API' do
    get "/attachments/#{@attachment_id}/scan"

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/#login-modal$}
    assert_not_requested(:get, "#{API_URL}/attachments/#{@attachment_id}/masked_text")
  end

  it 'SAD: redirects home when the API cannot scan the attachment' do
    stub_login
    WebMock.stub_request(:get, "#{API_URL}/attachments/#{@attachment_id}/masked_text")
           .to_return(
             status: 500,
             body: { message: 'Could not mask attachment' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'
    get "/attachments/#{@attachment_id}/scan"

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/$}
    stub_attachment_list
    follow_redirect!
    _(last_response.body).must_include 'Attachment scan is temporarily unavailable'
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

  def stub_scan
    WebMock.stub_request(:get, "#{API_URL}/attachments/#{@attachment_id}/masked_text")
           .with(headers: { 'Authorization' => "Bearer #{@account['auth_token']}" })
           .to_return(
             status: 200,
             body: {
               data: {
                 type: 'masked_attachment_text',
                 attributes: {
                   attachment_id: @attachment_id,
                   masked_text: 'Ada [EMAIL] [PHONE_NUMBER]',
                   matches: [
                     {
                       type: 'email',
                       value: 'ada@example.com',
                       start: 4,
                       end: 19,
                       source: 'pattern'
                     },
                     {
                       type: 'phone_number',
                       value: '0912-000-001',
                       start: 20,
                       end: 32,
                       source: 'pattern'
                     }
                   ]
                 }
               }
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end

  def stub_attachment_list
    WebMock.stub_request(:get, "#{API_URL}/attachments")
           .with(headers: { 'Authorization' => "Bearer #{@account['auth_token']}" })
           .to_return(
             status: 200,
             body: { data: [] }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
