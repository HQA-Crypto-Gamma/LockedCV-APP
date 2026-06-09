# frozen_string_literal: true

require_relative '../spec_helper'

describe 'DeleteMaskedAttachment service' do
  before do
    @attachment_id = 'attachment-id'
    @masked_attachment_id = 'masked-attachment-id'
    @auth_token = 'auth-token'
    @path = "#{API_URL}/attachments/#{@attachment_id}/masked_attachments/#{@masked_attachment_id}"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: deletes one masked attachment version with bearer auth' do
    WebMock.stub_request(:delete, @path)
           .with(headers: { 'Authorization' => "Bearer #{@auth_token}" })
           .to_return(
             status: 200,
             body: { message: 'Masked attachment deleted' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    response = LockedCV::DeleteMaskedAttachment.new(app.config).call(
      attachment_id: @attachment_id,
      masked_attachment_id: @masked_attachment_id,
      auth_token: @auth_token
    )

    _(response).must_equal('message' => 'Masked attachment deleted')
  end

  it 'BAD: raises NotFoundError when the masked attachment is missing' do
    WebMock.stub_request(:delete, @path)
           .to_return(
             status: 404,
             body: { message: 'Masked attachment not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::DeleteMaskedAttachment.new(app.config).call(
        attachment_id: @attachment_id,
        masked_attachment_id: @masked_attachment_id,
        auth_token: @auth_token
      )
    }).must_raise LockedCV::DeleteMaskedAttachment::NotFoundError
  end
end
