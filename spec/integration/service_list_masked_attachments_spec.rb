# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ListMaskedAttachments service' do
  before do
    @attachment_id = 'attachment-id'
    @path = "#{API_URL}/attachments/#{@attachment_id}/masked_attachments"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: returns saved masked attachment models' do
    WebMock.stub_request(:get, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: {
               data: [
                 {
                   data: {
                     attributes: {
                       id: 'masked-attachment-id',
                       attachment_id: @attachment_id,
                       attachment_name: 'masked_resume.pdf',
                       masked_items_count: 3,
                       created_at: '2026-06-09T20:30:00+08:00'
                     }
                   }
                 }
               ]
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    versions = LockedCV::ListMaskedAttachments.new(app.config).call(
      attachment_id: @attachment_id,
      auth_token: 'auth-token'
    )

    _(versions.length).must_equal 1
    _(versions.first).must_be_instance_of LockedCV::MaskedAttachment
    _(versions.first.id).must_equal 'masked-attachment-id'
    _(versions.first.attachment_id).must_equal @attachment_id
    _(versions.first.attachment_name).must_equal 'masked_resume.pdf'
    _(versions.first.masked_items_count).must_equal 3
    _(versions.first.created_at).must_equal '2026-06-09T20:30:00+08:00'
  end

  it 'BAD: raises NotFoundError when the API rejects the attachment' do
    WebMock.stub_request(:get, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 404,
             body: { message: 'Attachment not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::ListMaskedAttachments.new(app.config).call(
        attachment_id: @attachment_id,
        auth_token: 'auth-token'
      )
    }).must_raise LockedCV::ListMaskedAttachments::NotFoundError
  end
end
