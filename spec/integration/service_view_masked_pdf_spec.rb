# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ViewMaskedPdf service' do
  before do
    @attachment_id = 'attachment-id'
    @masked_attachment_id = 'masked-attachment-id'
    @path = "#{API_URL}/attachments/#{@attachment_id}/masked_attachments/#{@masked_attachment_id}/view"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: fetches an inline masked PDF for viewing' do
    WebMock.stub_request(:get, @path)
           .with(headers: { 'Accept' => 'application/pdf', 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: "%PDF-1.4\nshared",
             headers: { 'content-type' => 'application/pdf' }
           )

    pdf_body = LockedCV::ViewMaskedPdf.new(app.config).call(
      attachment_id: @attachment_id,
      masked_attachment_id: @masked_attachment_id,
      auth_token: 'auth-token'
    )

    _(pdf_body.byteslice(0, 4)).must_equal '%PDF'
  end

  it 'BAD: raises NotFoundError when the shared masked PDF is missing' do
    WebMock.stub_request(:get, @path)
           .to_return(
             status: 404,
             body: { message: 'Masked attachment not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::ViewMaskedPdf.new(app.config).call(
        attachment_id: @attachment_id,
        masked_attachment_id: @masked_attachment_id,
        auth_token: 'auth-token'
      )
    }).must_raise LockedCV::ViewMaskedPdf::NotFoundError
  end
end
