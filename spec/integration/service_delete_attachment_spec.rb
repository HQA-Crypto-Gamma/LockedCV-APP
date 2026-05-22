# frozen_string_literal: true

require_relative '../spec_helper'

describe 'DeleteAttachment service' do
  before do
    @account_id = 'account-id'
    @attachment_id = 'attachment-id'
    @auth_token = 'auth-token'
    @path = "#{API_URL}/accounts/#{@account_id}/attachments/#{@attachment_id}"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: deletes an attachment with bearer auth' do
    WebMock.stub_request(:delete, @path)
           .with(headers: { 'Authorization' => "Bearer #{@auth_token}" })
           .to_return(
             status: 200,
             body: { message: 'Attachment deleted' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    response = LockedCV::DeleteAttachment.new(app.config).call(
      account_id: @account_id,
      attachment_id: @attachment_id,
      auth_token: @auth_token
    )

    _(response).must_equal('message' => 'Attachment deleted')
  end

  it 'BAD: raises NotFoundError when attachment is missing' do
    WebMock.stub_request(:delete, @path)
           .to_return(
             status: 404,
             body: { message: 'Attachment not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::DeleteAttachment.new(app.config).call(
        account_id: @account_id,
        attachment_id: @attachment_id,
        auth_token: @auth_token
      )
    }).must_raise LockedCV::DeleteAttachment::NotFoundError
  end

  it 'BAD: raises UnauthorizedError when API rejects the token' do
    WebMock.stub_request(:delete, @path)
           .to_return(
             status: 403,
             body: { message: 'Forbidden account access' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::DeleteAttachment.new(app.config).call(
        account_id: @account_id,
        attachment_id: @attachment_id,
        auth_token: @auth_token
      )
    }).must_raise LockedCV::DeleteAttachment::UnauthorizedError
  end

  it 'BAD: raises ServiceUnavailableError when API fails' do
    WebMock.stub_request(:delete, @path)
           .to_return(
             status: 500,
             body: { message: 'boom' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::DeleteAttachment.new(app.config).call(
        account_id: @account_id,
        attachment_id: @attachment_id,
        auth_token: @auth_token
      )
    }).must_raise LockedCV::DeleteAttachment::ServiceUnavailableError
  end
end
