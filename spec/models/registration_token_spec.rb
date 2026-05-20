# frozen_string_literal: true

require_relative '../spec_helper'

describe LockedCV::RegistrationToken do
  it 'HAPPY: loads email and username from a registration token' do
    token = LockedCV::RegistrationToken.new(
      email: 'grace@example.com',
      username: 'grace-hopper'
    ).to_s

    loaded = LockedCV::RegistrationToken.load(token)

    _(loaded.email).must_equal 'grace@example.com'
    _(loaded.username).must_equal 'grace-hopper'
    _(loaded.to_s).must_equal token
  end

  it 'SECURITY: does not expose email or username in the token text' do
    token = LockedCV::RegistrationToken.new(
      email: 'grace@example.com',
      username: 'grace-hopper'
    ).to_s

    _(token).wont_include 'grace@example.com'
    _(token).wont_include 'grace-hopper'
  end

  it 'SECURITY: rejects tampered registration tokens' do
    token = LockedCV::RegistrationToken.new(
      email: 'grace@example.com',
      username: 'grace-hopper'
    ).to_s
    tampered = token.dup
    tampered[-2] = tampered[-2] == 'A' ? 'B' : 'A'

    _ { LockedCV::RegistrationToken.load(tampered) }
      .must_raise LockedCV::RegistrationToken::InvalidTokenError
  end
end
