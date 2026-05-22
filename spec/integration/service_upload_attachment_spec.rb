# frozen_string_literal: true

require 'tempfile'
require_relative '../spec_helper'

describe 'UploadAttachment service' do
  before do
    @account_id = 'account-id'
    @auth_token = 'auth-token'
    @path = "#{API_URL}/accounts/#{@account_id}/attachments/upload"
    @attachment_attributes = {
      'id' => 'attachment-id',
      'attachment_name' => 'resume.pdf',
      'route' => 'accounts/account-id/resume_abc123.pdf'
    }
    @pdf = Tempfile.new(['lockedcv-app-upload', '.pdf'])
    @pdf.write('%PDF-1.4 test')
    @pdf.rewind
    @uploaded_file = {
      filename: 'resume.pdf',
      type: 'application/pdf',
      tempfile: @pdf
    }
  end

  after do
    @pdf&.close!
    WebMock.reset!
  end

  it 'HAPPY: uploads a PDF with bearer auth and returns attachment attributes' do
    WebMock.stub_request(:post, @path)
           .with(headers: { 'Authorization' => "Bearer #{@auth_token}" }) do |request|
             request.body.include?('name="file"') &&
               request.body.include?('filename="resume.pdf"') &&
               request.body.include?('name="original_filename"') &&
               request.body.include?('resume.pdf')
           end
           .to_return(
             status: 201,
             body: { data: { data: { attributes: @attachment_attributes } } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    attachment = LockedCV::UploadAttachment.new(app.config).call(
      account_id: @account_id,
      auth_token: @auth_token,
      uploaded_file: @uploaded_file
    )

    _(attachment).must_equal @attachment_attributes
  end

  it 'BAD: validates missing files before calling API' do
    error = _(proc {
      LockedCV::UploadAttachment.new(app.config).call(
        account_id: @account_id,
        auth_token: @auth_token,
        uploaded_file: nil
      )
    }).must_raise LockedCV::UploadAttachment::ValidationError

    _(error.message).must_equal 'Please choose a PDF file to upload'
    assert_not_requested(:post, @path)
  end

  it 'BAD: raises ValidationError when API rejects the upload' do
    WebMock.stub_request(:post, @path)
           .to_return(
             status: 400,
             body: { message: 'Could not upload attachment' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::UploadAttachment.new(app.config).call(
        account_id: @account_id,
        auth_token: @auth_token,
        uploaded_file: @uploaded_file
      )
    }).must_raise LockedCV::UploadAttachment::ValidationError
  end
end
