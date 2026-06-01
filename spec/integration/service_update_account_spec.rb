# frozen_string_literal: true

require_relative '../spec_helper'

describe 'UpdateAccount service' do
  before do
    @current_account = current_account
    @profile_data = {
      email: 'grace@example.com',
      phone_number: '',
      first_name: 'Grace',
      last_name: 'Hopper',
      birthday: '',
      address: '',
      identification_numbers: ''
    }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: sends normalized profile payload to API' do
    updated_attributes = @profile_data.merge(
      phone_number: nil,
      birthday: nil,
      address: nil,
      identification_numbers: nil
    ).transform_keys(&:to_s)

    WebMock.stub_request(:put, "#{API_URL}/account")
           .with(
             body: {
               email: 'grace@example.com',
               phone_number: nil,
               first_name: 'Grace',
               last_name: 'Hopper',
               birthday: nil,
               address: nil,
               identification_numbers: nil
             }.to_json,
             headers: { 'Authorization' => 'Bearer auth-token' }
           )
           .to_return(
             status: 200,
             body: {
               data: {
                 data: {
                   attributes: updated_attributes
                 }
               }
             }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    account = LockedCV::UpdateAccount.new(app.config, current_account: @current_account).call(
      profile_data: @profile_data
    )

    _(account).must_equal updated_attributes
    assert_requested(:put, "#{API_URL}/account")
  end

  it 'BAD: raises ValidationError when API rejects profile data' do
    WebMock.stub_request(:put, "#{API_URL}/account")
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 400,
             body: { message: 'Email is already registered' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    error = _(proc {
      LockedCV::UpdateAccount.new(app.config, current_account: @current_account).call(
        profile_data: @profile_data
      )
    }).must_raise LockedCV::UpdateAccount::ValidationError
    _(error.message).must_equal 'Email is already registered'
  end
end
