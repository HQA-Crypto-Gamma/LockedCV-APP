# frozen_string_literal: true

require_relative '../spec_helper'

describe 'RedeemMaskedAttachmentShareLink service' do
  before do
    @token = 'share-token'
    @path = "#{API_URL}/masked_attachment_share_links/#{@token}/redeem"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: redeems a masked attachment share link' do
    WebMock.stub_request(:post, @path)
           .with(body: '{}', headers: { 'Authorization' => 'Bearer auth-token' })
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

    redemption = LockedCV::RedeemMaskedAttachmentShareLink.new(app.config).call(
      token: @token,
      auth_token: 'auth-token'
    )

    _(redemption['attachment_id']).must_equal 'attachment-id'
    _(redemption['masked_attachment_id']).must_equal 'masked-attachment-id'
    _(redemption['role']).must_equal 'viewer_masked'
  end

  it 'BAD: raises NotFoundError when the token is invalid' do
    WebMock.stub_request(:post, @path)
           .to_return(
             status: 404,
             body: { message: 'Masked attachment share link not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::RedeemMaskedAttachmentShareLink.new(app.config).call(
        token: @token,
        auth_token: 'auth-token'
      )
    }).must_raise LockedCV::RedeemMaskedAttachmentShareLink::NotFoundError
  end
end
