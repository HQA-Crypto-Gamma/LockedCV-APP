# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Home flow' do
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

  it 'HAPPY: labels masked shared attachments without delete actions' do
    stub_login
    stub_masked_attachment_list

    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'
    get '/'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'shared_resume.pdf'
    _(last_response.body).must_include 'Masked shared copy'
    _(last_response.body).must_include 'Masked versions'
    _(last_response.body).must_include '2026-06-09 20:41:04 +0800'
    _(last_response.body).wont_include '<th>Risk</th>'
    _(last_response.body).must_include '/attachments/shared-attachment-id/masked_attachments'
    _(last_response.body).must_include 'version-count--link'
    _(last_response.body).wont_include 'Delete shared_resume.pdf'
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

  def stub_masked_attachment_list
    WebMock.stub_request(:get, "#{API_URL}/attachments")
           .with(headers: { 'Authorization' => "Bearer #{@account['auth_token']}" })
           .to_return(
             status: 200,
             body: {
               data: [
                 {
                   data: {
                     attributes: {
                       'id' => 'shared-attachment-id',
                       'attachment_name' => 'shared_resume.pdf',
                       'masked_attachments_count' => 1,
                       'created_at' => '2026-06-09 20:41:04 +0800'
                     }
                   },
                   policy: {
                     can_view: false,
                     can_view_masked: true,
                     can_delete: false,
                     role: 'viewer_masked'
                   }
                 }
               ]
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
