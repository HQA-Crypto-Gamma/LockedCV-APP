# frozen_string_literal: true

require_relative '../spec_helper'

describe 'StringSecurity.entropy' do
  it 'HAPPY: empty and nil strings have zero entropy' do
    _(LockedCV::StringSecurity.entropy('')).must_equal 0.0
    _(LockedCV::StringSecurity.entropy(nil)).must_equal 0.0
  end

  it 'HAPPY: matches reference values within tolerance' do
    _(LockedCV::StringSecurity.entropy('adf')).must_be_close_to 1.58, 0.05
    _(LockedCV::StringSecurity.entropy('@3Fs^1HfaF$2')).must_be_close_to 3.41, 0.05
  end

  it 'SAD: long uniform strings have low entropy' do
    _(LockedCV::StringSecurity.entropy('aaaaaaaa')).must_equal 0.0
    _(LockedCV::StringSecurity.entropy('abababab')).must_be :<, 1.5
  end
end
