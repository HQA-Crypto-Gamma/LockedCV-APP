# frozen_string_literal: true

require_relative '../spec_helper'

describe 'DownloadMaskedPdf service' do
  before do
    @auth_token = 'auth-token'
    @attachment_id = 'attachment-id'
    @masked_attachment_id = 'masked-attachment-id'
    @path = "#{API_URL}/attachments/#{@attachment_id}/masked_attachments/#{@masked_attachment_id}/encrypted_download"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: downloads a password-protected masked PDF' do
    WebMock.stub_request(:post, @path)
           .with(
             body: { password: 'test123' }.to_json,
             headers: { 'Authorization' => "Bearer #{@auth_token}" }
           )
           .to_return(
             status: 200,
             body: "%PDF-1.4\nencrypted masked",
             headers: { 'content-type' => 'application/pdf' }
           )

    pdf_body = LockedCV::DownloadMaskedPdf.new(app.config).call(
      attachment_id: @attachment_id,
      masked_attachment_id: @masked_attachment_id,
      auth_token: @auth_token,
      password: 'test123'
    )

    _(pdf_body.byteslice(0, 4)).must_equal '%PDF'
  end

  it 'BAD: raises NotFoundError when masked attachment is missing' do
    WebMock.stub_request(:post, @path)
           .to_return(
             status: 404,
             body: { message: 'Masked attachment not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::DownloadMaskedPdf.new(app.config).call(
        attachment_id: @attachment_id,
        masked_attachment_id: @masked_attachment_id,
        auth_token: @auth_token,
        password: 'test123'
      )
    }).must_raise LockedCV::DownloadMaskedPdf::NotFoundError
  end
end
