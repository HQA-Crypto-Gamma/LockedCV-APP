# frozen_string_literal: true

require 'tempfile'
require_relative '../spec_helper'

describe 'Attachment upload route' do
  before do
    @account = {
      'id' => 'account-id',
      'username' => 'ada-lovelace',
      'email' => 'ada@example.com',
      'roles' => ['member'],
      'auth_token' => 'auth-token'
    }
    @pdf = Tempfile.new(['lockedcv-app-route-upload', '.pdf'])
    @pdf.write('%PDF-1.4 test')
    @pdf.rewind
  end

  after do
    @pdf&.close!
    WebMock.reset!
  end

  it 'HAPPY: uploads the selected PDF for the logged-in account' do
    stub_login
    stub_upload

    post '/auth/login', username: 'ada-lovelace', password: 'ada-secret'
    upload = Rack::Test::UploadedFile.new(@pdf.path, 'application/pdf', true, original_filename: 'resume.pdf')
    post '/attachments/upload', cv: upload

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/$}
    assert_requested(:post, "#{API_URL}/accounts/#{@account['id']}/attachments/upload")
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

  def stub_upload
    WebMock.stub_request(:post, "#{API_URL}/accounts/#{@account['id']}/attachments/upload")
           .with(headers: { 'Authorization' => "Bearer #{@account['auth_token']}" })
           .to_return(
             status: 201,
             body: { data: { data: { attributes: { 'attachment_name' => 'resume.pdf' } } } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end
end
