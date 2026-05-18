# frozen_string_literal: true

require_relative '../spec_helper'

describe 'AssignSystemRole service' do
  before do
    @current_account = current_account
    @target_username = 'alan-turing'
    @role_name = 'admin'
    @account_attributes = {
      'username' => @target_username,
      'roles' => ['admin']
    }
    @path = "#{API_URL}/accounts/#{@target_username}/system_roles/#{@role_name}"
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: assigns system role and returns target account attributes' do
    WebMock.stub_request(:put, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 200,
             body: { data: { data: { attributes: @account_attributes } } }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    account = LockedCV::AssignSystemRole.new(app.config, current_account: @current_account).call(
      target_username: @target_username,
      role_name: @role_name
    )

    _(account).must_equal @account_attributes
  end

  it 'BAD: raises UnauthorizedError when caller is not admin' do
    WebMock.stub_request(:put, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 403,
             body: { message: 'Only admins can manage system roles' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::AssignSystemRole.new(app.config, current_account: @current_account).call(
        target_username: @target_username,
        role_name: @role_name
      )
    }).must_raise LockedCV::AssignSystemRole::UnauthorizedError
  end

  it 'BAD: raises ValidationError for unknown role or account' do
    WebMock.stub_request(:put, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 404,
             body: { message: 'Account not found' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::AssignSystemRole.new(app.config, current_account: @current_account).call(
        target_username: @target_username,
        role_name: @role_name
      )
    }).must_raise LockedCV::AssignSystemRole::ValidationError
  end

  it 'BAD: raises ServiceUnavailableError when API fails' do
    WebMock.stub_request(:put, @path)
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(
             status: 500,
             body: { message: 'boom' }.to_json,
             headers: { 'content-type' => 'application/json' }
           )

    _(proc {
      LockedCV::AssignSystemRole.new(app.config, current_account: @current_account).call(
        target_username: @target_username,
        role_name: @role_name
      )
    }).must_raise LockedCV::AssignSystemRole::ServiceUnavailableError
  end
end
