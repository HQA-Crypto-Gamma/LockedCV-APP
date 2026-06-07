# frozen_string_literal: true

require_relative '../spec_helper'

describe 'CreateMaskedPdf service' do
  before do
    @auth_token = 'auth-token'
    @attachment_id = 'attachment-id'
    @path = "#{API_URL}/attachments/#{@attachment_id}/masked_attachments"
    @masked_attachment = {
      'id' => 'masked-attachment-id',
      'attachment_id' => @attachment_id,
      'attachment_name' => 'masked_resume.pdf',
      'route' => 'accounts/account-id/masked/masked_resume.pdf'
    }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: creates a saved masked PDF for selected mask labels' do
    WebMock.stub_request(:post, @path)
           .with(
             body: { selected_labels: %w[email tel] }.to_json,
             headers: { 'Authorization' => "Bearer #{@auth_token}" }
           )
           .to_return(
             status: 201,
             body: {
               message: 'Masked attachment saved',
               data: {
                 data: {
                   type: 'masked_attachment',
                   attributes: @masked_attachment
                 }
               }
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    masked_attachment = LockedCV::CreateMaskedPdf.new(app.config).call(
      attachment_id: @attachment_id,
      auth_token: @auth_token,
      selected_labels: %w[email tel]
    )

    _(masked_attachment).must_equal @masked_attachment
  end

  it 'BAD: raises ValidationError when API rejects selected labels' do
    WebMock.stub_request(:post, @path)
           .to_return(
             status: 400,
             body: { message: 'Invalid selected labels' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::CreateMaskedPdf.new(app.config).call(
        attachment_id: @attachment_id,
        auth_token: @auth_token,
        selected_labels: ['unknown']
      )
    }).must_raise LockedCV::CreateMaskedPdf::ValidationError
  end
end
