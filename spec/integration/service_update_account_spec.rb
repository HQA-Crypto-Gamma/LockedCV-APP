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

  it 'BAD: validates birthday format before calling API' do
    invalid_data = @profile_data.merge(birthday: '1906/12/09')

    error = _(proc {
      LockedCV::UpdateAccount.new(app.config, current_account: @current_account).call(
        profile_data: invalid_data
      )
    }).must_raise LockedCV::UpdateAccount::ValidationError
    _(error.message).must_equal 'Birthday must use YYYY-MM-DD format'
    assert_not_requested(:put, "#{API_URL}/account")
  end
end
