# frozen_string_literal: true

require 'base64'
require 'rbnacl'
require_relative '../spec_helper'

describe 'SignedMessage' do
  before do
    @original_signing_key = LockedCV::SignedMessage.instance_variable_get(:@signing_key)
    @signing_key = RbNaCl::SigningKey.generate
    @message = { username: 'ada-lovelace', password: 'secret' }
    LockedCV::SignedMessage.setup(Base64.strict_encode64(@signing_key.to_bytes))
  end

  after do
    LockedCV::SignedMessage.instance_variable_set(:@signing_key, @original_signing_key)
  end

  it 'HAPPY: returns data and a verifiable signature' do
    signed = LockedCV::SignedMessage.sign(@message)

    _(signed[:data]).must_equal @message
    signature = Base64.strict_decode64(signed[:signature])
    _(@signing_key.verify_key.verify(signature, @message.to_json)).must_equal true
  end

  it 'BAD: rejects invalid setup keys' do
    _ do
      LockedCV::SignedMessage.setup('not-base64')
    end.must_raise LockedCV::SignedMessage::KeypairError
  end

  it 'SECURITY: cannot sign without a signing key' do
    LockedCV::SignedMessage.instance_variable_set(:@signing_key, nil)

    _ do
      LockedCV::SignedMessage.sign(@message)
    end.must_raise LockedCV::SignedMessage::KeypairError
  end
end
