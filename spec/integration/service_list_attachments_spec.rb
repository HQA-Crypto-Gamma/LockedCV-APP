# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ListAttachments service' do
  before do
    @current_account = current_account
    @attachment_attributes = {
      'id' => 'attachment-id',
      'attachment_name' => 'resume.pdf'
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
                   policy: { can_delete: true }
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
    _(attachments.first.can_delete?).must_equal true
  end

  it 'HAPPY: returns attachment models without delete permission from policy' do
    WebMock.stub_request(:get, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: {
               data: [
                 {
                   data: { attributes: @attachment_attributes },
                   policy: { can_delete: false }
                 }
               ]
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    attachments = LockedCV::ListAttachments.new(app.config, current_account: @current_account).call

    _(attachments.first.id).must_equal 'attachment-id'
    _(attachments.first.attachment_name).must_equal 'resume.pdf'
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
