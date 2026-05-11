# frozen_string_literal: true

require_relative '../spec_helper'

describe 'RegisterAccount service' do
  before do
    @registration_data = {
      username: 'grace-hopper',
      email: 'grace@example.com',
      phone_number: '',
      first_name: 'Grace',
      last_name: 'Hopper',
      birthday: '',
      address: '',
      identification_numbers: '',
      password: 'grace-secret'
    }
    @expected_payload = @registration_data.merge(
      phone_number: nil,
      birthday: nil,
      address: nil,
      identification_numbers: nil
    )
    @account_attributes = {
      'id' => 'account-id',
      'username' => 'grace-hopper',
      'email' => 'grace@example.com',
      'roles' => ['member']
    }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: posts registration payload and returns account attributes' do
    WebMock.stub_request(:post, "#{API_URL}/accounts")
           .with(body: @expected_payload.to_json)
           .to_return(
             status: 201,
             body: { data: { data: { attributes: @account_attributes } } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    account = LockedCV::RegisterAccount.new(app.config).call(@registration_data)

    _(account).must_equal @account_attributes
  end

  it 'BAD: validates username, email, and password before calling API' do
    invalid_data = @registration_data.merge(email: '')

    _(proc {
      LockedCV::RegisterAccount.new(app.config).call(invalid_data)
    }).must_raise LockedCV::RegisterAccount::ValidationError
    assert_not_requested(:post, "#{API_URL}/accounts")
  end

  it 'BAD: raises ValidationError on API validation failure' do
    WebMock.stub_request(:post, "#{API_URL}/accounts")
           .with(body: @expected_payload.to_json)
           .to_return(
             status: 400,
             body: { message: 'Illegal Attributes' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::RegisterAccount.new(app.config).call(@registration_data)
    }).must_raise LockedCV::RegisterAccount::ValidationError
  end

  it 'BAD: raises ServiceUnavailableError when API fails' do
    WebMock.stub_request(:post, "#{API_URL}/accounts")
           .with(body: @expected_payload.to_json)
           .to_return(
             status: 500,
             body: { message: 'boom' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::RegisterAccount.new(app.config).call(@registration_data)
    }).must_raise LockedCV::RegisterAccount::ServiceUnavailableError
  end
end
