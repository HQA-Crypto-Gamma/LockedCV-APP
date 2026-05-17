# frozen_string_literal: true

module LockedCV
  # Identity parser model: wraps account info and API-issued auth token.
  class Account
    attr_reader :account_info, :auth_token

    def initialize(account_info, auth_token)
      @account_info = account_info
      @auth_token = auth_token
    end

    def logged_in?
      !@account_info.nil? && !@auth_token.nil?
    end

    def logged_out?
      !logged_in?
    end

    def id
      attributes&.dig('id')
    end

    def username
      attributes&.dig('username')
    end

    def email
      attributes&.dig('email')
    end

    def admin?
      roles.include?('admin')
    end

    def member?
      roles.include?('member')
    end

    def roles
      attributes&.dig('roles') || []
    end

    private

    def attributes
      @account_info && @account_info['attributes']
    end
  end
end
