# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ListAttachments service' do
  before do
    @account_id = 'account-id'
    @attachment_attributes = {
      'id' => 'attachment-id',
      'attachment_name' => 'resume.pdf'
    }
    @path = "#{API_URL}/accounts/#{@account_id}/attachments"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: returns attachment attributes for account' do
    WebMock.stub_request(:get, @path)
           .to_return(
             status: 200,
             body: {
               data: [
                 { data: { attributes: @attachment_attributes } }
               ]
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    attachments = LockedCV::ListAttachments.new(app.config).call(account_id: @account_id)

    _(attachments).must_equal [@attachment_attributes]
  end

  it 'BAD: raises ServiceUnavailableError when API fails' do
    WebMock.stub_request(:get, @path)
           .to_return(
             status: 500,
             body: { message: 'boom' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::ListAttachments.new(app.config).call(account_id: @account_id)
    }).must_raise LockedCV::ListAttachments::ServiceUnavailableError
  end
end
