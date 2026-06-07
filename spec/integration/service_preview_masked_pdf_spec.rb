# frozen_string_literal: true

require_relative '../spec_helper'

describe 'PreviewMaskedPdf service' do
  before do
    @auth_token = 'auth-token'
    @attachment_id = 'attachment-id'
    @path = "#{API_URL}/attachments/#{@attachment_id}/masked_attachments/preview"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: fetches a PDF preview for selected mask labels' do
    WebMock.stub_request(:post, @path)
           .with(
             body: { selected_labels: %w[email tel] }.to_json,
             headers: { 'Authorization' => "Bearer #{@auth_token}" }
           )
           .to_return(
             status: 200,
             body: "%PDF-1.4\npreview",
             headers: { 'content-type' => 'application/pdf' }
           )

    pdf_body = LockedCV::PreviewMaskedPdf.new(app.config).call(
      attachment_id: @attachment_id,
      auth_token: @auth_token,
      selected_labels: %w[email tel]
    )

    _(pdf_body.byteslice(0, 4)).must_equal '%PDF'
  end

  it 'BAD: raises ValidationError when API rejects selected labels' do
    WebMock.stub_request(:post, @path)
           .to_return(
             status: 400,
             body: { message: 'Invalid selected labels' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::PreviewMaskedPdf.new(app.config).call(
        attachment_id: @attachment_id,
        auth_token: @auth_token,
        selected_labels: ['unknown']
      )
    }).must_raise LockedCV::PreviewMaskedPdf::ValidationError
  end
end
