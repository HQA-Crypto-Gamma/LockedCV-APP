# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Masked attachment share flow' do
  before do
    @account = {
      'id' => 'recipient-account-id',
      'username' => 'grace-hopper',
      'email' => 'grace@example.com',
      'roles' => ['member'],
      'auth_token' => 'recipient-auth-token'
    }
    @token = 'share-token'
    @share_path = "/share/masked-attachments/#{@token}"
    @redeem_path = "#{API_URL}/masked_attachment_share_links/#{@token}/redeem"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: stores share redirect for guests and redeems after login' do
    stub_login
    stub_redeem_share_link

    get @share_path

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/#login-modal$}
    assert_not_requested(:post, @redeem_path)

    post '/auth/login', username: 'grace-hopper', password: 'grace-secret'

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/share/masked-attachments/#{@token}$}

    follow_redirect!

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/shared/masked-attachments/attachment-id/masked-attachment-id$}
    assert_requested(
      :post,
      @redeem_path,
      body: '{}',
      headers: { 'Authorization' => "Bearer #{@account['auth_token']}" }
    )
  end

  it 'HAPPY: redeems a share link for an already logged-in account' do
    stub_login
    stub_redeem_share_link

    post '/auth/login', username: 'grace-hopper', password: 'grace-secret'
    get @share_path

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/shared/masked-attachments/attachment-id/masked-attachment-id$}
    assert_requested(:post, @redeem_path)
  end

  it 'HAPPY: shows a read-only shared masked PDF viewer for a logged-in account' do
    stub_login

    post '/auth/login', username: 'grace-hopper', password: 'grace-secret'
    get '/shared/masked-attachments/attachment-id/masked-attachment-id'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Shared masked PDF'
    _(last_response.body).must_include 'Read only'
    _(last_response.body).must_include '/shared/masked-attachments/attachment-id/masked-attachment-id/pdf'
    _(last_response.body).wont_include 'data-version-download-button'
    _(last_response.body).wont_include 'data-version-share-button'
    _(last_response.body).wont_include 'Delete shared_masked_attachment'
  end

  it 'HAPPY: returns the shared masked PDF inline for a logged-in account' do
    stub_login
    stub_view_shared_pdf

    post '/auth/login', username: 'grace-hopper', password: 'grace-secret'
    get '/shared/masked-attachments/attachment-id/masked-attachment-id/pdf'

    _(last_response.status).must_equal 200
    _(last_response.headers['Content-Type']).must_include 'application/pdf'
    _(last_response.headers['Content-Disposition']).must_equal 'inline; filename="shared_masked_attachment.pdf"'
    _(last_response.body.byteslice(0, 4)).must_equal '%PDF'
    assert_requested(
      :get,
      "#{API_URL}/attachments/attachment-id/masked_attachments/masked-attachment-id/view",
      headers: { 'Authorization' => "Bearer #{@account['auth_token']}" }
    )
  end

  it 'SAD: redirects home when the share token is invalid' do
    stub_login
    WebMock.stub_request(:post, @redeem_path)
           .to_return(
             status: 404,
             body: { message: 'Masked attachment share link not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    post '/auth/login', username: 'grace-hopper', password: 'grace-secret'
    get @share_path

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/$}
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

  def stub_redeem_share_link
    WebMock.stub_request(:post, @redeem_path)
           .with(
             body: '{}',
             headers: { 'Authorization' => "Bearer #{@account['auth_token']}" }
           )
           .to_return(
             status: 200,
             body: {
               message: 'Masked attachment share link redeemed',
               data: {
                 type: 'masked_attachment_share_link_redemption',
                 attributes: {
                   attachment_id: 'attachment-id',
                   masked_attachment_id: 'masked-attachment-id',
                   role: 'viewer_masked'
                 }
               }
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )
  end

  def stub_view_shared_pdf
    WebMock.stub_request(:get, "#{API_URL}/attachments/attachment-id/masked_attachments/masked-attachment-id/view")
           .with(headers: { 'Authorization' => "Bearer #{@account['auth_token']}" })
           .to_return(
             status: 200,
             body: "%PDF-1.4\nshared",
             headers: { 'content-type' => 'application/pdf' }
           )
  end
end
