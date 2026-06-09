# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ListAttachments service' do
  before do
    @current_account = current_account
    @attachment_attributes = {
      'id' => 'attachment-id',
      'attachment_name' => 'resume.pdf',
      'masked_attachments_count' => 2,
      'created_at' => '2026-06-09 20:41:04 +0800'
    }
    @path = "#{API_URL}/attachments"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: returns attachment models with delete permission from policy' do
    WebMock.stub_request(:get, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: {
               data: [
                 {
                   data: { attributes: @attachment_attributes },
                   policy: {
                     can_view: true,
                     can_view_masked: true,
                     can_delete: true,
                     role: 'owner'
                   }
                 }
               ]
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    attachments = LockedCV::ListAttachments.new(app.config, current_account: @current_account).call

    _(attachments.length).must_equal 1
    _(attachments.first).must_be_instance_of LockedCV::Attachment
    _(attachments.first.id).must_equal 'attachment-id'
    _(attachments.first.attachment_name).must_equal 'resume.pdf'
    _(attachments.first.masked_attachments_count).must_equal 2
    _(attachments.first.masked_versions?).must_equal true
    _(attachments.first.created_at).must_equal '2026-06-09 20:41:04 +0800'
    _(attachments.first.uploaded_at).must_equal '2026-06-09 20:41:04 +0800'
    _(attachments.first.role).must_equal 'owner'
    _(attachments.first.owner?).must_equal true
    _(attachments.first.viewer_masked?).must_equal false
    _(attachments.first.can_view?).must_equal true
    _(attachments.first.can_view_masked?).must_equal true
    _(attachments.first.can_delete?).must_equal true
  end

  it 'HAPPY: returns attachment models for masked viewers from policy' do
    WebMock.stub_request(:get, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: {
               data: [
                 {
                   data: { attributes: @attachment_attributes },
                   policy: {
                     can_view: false,
                     can_view_masked: true,
                     can_delete: false,
                     role: 'viewer_masked'
                   }
                 }
               ]
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    attachments = LockedCV::ListAttachments.new(app.config, current_account: @current_account).call

    _(attachments.first.id).must_equal 'attachment-id'
    _(attachments.first.attachment_name).must_equal 'resume.pdf'
    _(attachments.first.masked_attachments_count).must_equal 2
    _(attachments.first.role).must_equal 'viewer_masked'
    _(attachments.first.owner?).must_equal false
    _(attachments.first.viewer_masked?).must_equal true
    _(attachments.first.can_view?).must_equal false
    _(attachments.first.can_view_masked?).must_equal true
    _(attachments.first.can_delete?).must_equal false
  end

  it 'HAPPY: defaults missing policy to no delete permission' do
    WebMock.stub_request(:get, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: {
               data: [
                 { data: { attributes: @attachment_attributes } }
               ]
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    attachments = LockedCV::ListAttachments.new(app.config, current_account: @current_account).call

    _(attachments.first.id).must_equal 'attachment-id'
    _(attachments.first.attachment_name).must_equal 'resume.pdf'
    _(attachments.first.masked_attachments_count).must_equal 2
    _(attachments.first.role).must_be_nil
    _(attachments.first.owner?).must_equal false
    _(attachments.first.viewer_masked?).must_equal false
    _(attachments.first.can_view?).must_equal false
    _(attachments.first.can_view_masked?).must_equal false
    _(attachments.first.can_delete?).must_equal false
  end

  it 'BAD: raises ServiceUnavailableError when API fails' do
    WebMock.stub_request(:get, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 500,
             body: { message: 'boom' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::ListAttachments.new(app.config, current_account: @current_account).call
    }).must_raise LockedCV::ListAttachments::ServiceUnavailableError
  end
end
