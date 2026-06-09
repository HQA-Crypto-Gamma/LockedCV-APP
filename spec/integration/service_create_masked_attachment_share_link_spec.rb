# frozen_string_literal: true

require_relative '../spec_helper'

describe 'CreateMaskedAttachmentShareLink service' do
  before do
    @attachment_id = 'attachment-id'
    @masked_attachment_id = 'masked-attachment-id'
    @path = "#{API_URL}/attachments/#{@attachment_id}/masked_attachments/#{@masked_attachment_id}/share_links"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: creates a masked attachment share link' do
    WebMock.stub_request(:post, @path)
           .with(body: '{}', headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 201,
             body: {
               message: 'Masked attachment share link created',
               data: {
                 type: 'masked_attachment_share_link',
                 attributes: {
                   token: 'share-token',
                   attachment_id: @attachment_id,
                   masked_attachment_id: @masked_attachment_id,
                   share_url: '/share/masked-attachments/share-token'
                 }
               }
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    share_link = LockedCV::CreateMaskedAttachmentShareLink.new(app.config).call(
      attachment_id: @attachment_id,
      masked_attachment_id: @masked_attachment_id,
      auth_token: 'auth-token'
    )

    _(share_link['token']).must_equal 'share-token'
    _(share_link['share_url']).must_equal '/share/masked-attachments/share-token'
  end

  it 'BAD: raises NotFoundError when the API rejects the masked attachment' do
    WebMock.stub_request(:post, @path)
           .to_return(
             status: 404,
             body: { message: 'Masked attachment not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::CreateMaskedAttachmentShareLink.new(app.config).call(
        attachment_id: @attachment_id,
        masked_attachment_id: @masked_attachment_id,
        auth_token: 'auth-token'
      )
    }).must_raise LockedCV::CreateMaskedAttachmentShareLink::NotFoundError
  end
end
