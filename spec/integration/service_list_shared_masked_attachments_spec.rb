# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ListSharedMaskedAttachments service' do
  before do
    @path = "#{API_URL}/shared_masked_attachments"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: returns shared masked attachment models' do
    WebMock.stub_request(:get, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: {
               data: [
                 {
                   data: {
                     attributes: {
                       attachment_id: 'attachment-id',
                       masked_attachment_id: 'masked-attachment-id',
                       attachment_name: 'resume.pdf',
                       masked_attachment_name: 'masked_resume.pdf',
                       masked_items_count: 2,
                       shared_at: '2026-06-09 22:43:49 +0800'
                     }
                   }
                 }
               ]
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    shared = LockedCV::ListSharedMaskedAttachments.new(
      app.config,
      current_account: Struct.new(:auth_token).new('auth-token')
    ).call

    _(shared.length).must_equal 1
    _(shared.first).must_be_instance_of LockedCV::SharedMaskedAttachment
    _(shared.first.attachment_id).must_equal 'attachment-id'
    _(shared.first.masked_attachment_id).must_equal 'masked-attachment-id'
    _(shared.first.display_name).must_equal 'masked_resume.pdf'
    _(shared.first.masked_items_count).must_equal 2
    _(shared.first.shared_at).must_equal '2026-06-09 22:43:49 +0800'
  end

  it 'BAD: raises ServiceUnavailableError when the API is unavailable' do
    WebMock.stub_request(:get, @path)
           .to_return(
             status: 503,
             body: '<!DOCTYPE html>',
             headers: { 'content-type' => 'text/html' }
           )

    _(proc {
      LockedCV::ListSharedMaskedAttachments.new(
        app.config,
        current_account: Struct.new(:auth_token).new('auth-token')
      ).call
    }).must_raise LockedCV::ListSharedMaskedAttachments::ServiceUnavailableError
  end
end
