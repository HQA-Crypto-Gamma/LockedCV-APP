# frozen_string_literal: true

require_relative '../spec_helper'
require 'tempfile'

describe 'Form validation contracts' do
  it 'validates login credentials presence' do
    result = LockedCV::Form::LoginCredentials.call(username: 'ada-lovelace', password: 'secret')

    _(result.success?).must_equal true
  end

  it 'rejects empty login credentials' do
    result = LockedCV::Form::LoginCredentials.call(username: '', password: '')

    _(result.success?).must_equal false
    _(LockedCV::Form.validation_errors(result).keys).must_include :username
    _(LockedCV::Form.validation_errors(result).keys).must_include :password
  end

  it 'validates registration start input' do
    result = LockedCV::Form::RegistrationStart.call(
      username: 'ada-lovelace',
      email: 'ada@example.com'
    )

    _(result.success?).must_equal true
  end

  it 'rejects registration usernames shorter than four characters' do
    result = LockedCV::Form::RegistrationStart.call(
      username: 'ad',
      email: 'ada@example.com'
    )

    _(result.success?).must_equal false
    _(LockedCV::Form.validation_errors(result)[:username]).must_match(/4-40/)
  end

  it 'rejects non-ASCII registration usernames' do
    result = LockedCV::Form::RegistrationStart.call(
      username: '阿達',
      email: 'ada@example.com'
    )

    _(result.success?).must_equal false
    _(LockedCV::Form.validation_errors(result)[:username]).must_match(/ASCII/)
  end

  it 'validates registration password confirmation and entropy' do
    result = LockedCV::Form::RegistrationPassword.call(
      password: '@3Fs^1HfaF$2',
      password_confirmation: '@3Fs^1HfaF$2'
    )

    _(result.success?).must_equal true
  end

  it 'rejects weak registration passwords' do
    result = LockedCV::Form::RegistrationPassword.call(
      password: 'aaaaaaaa',
      password_confirmation: 'aaaaaaaa'
    )

    _(result.success?).must_equal false
    _(LockedCV::Form.validation_errors(result)[:password]).must_match(/predictable/)
  end

  it 'rejects mismatched registration passwords' do
    result = LockedCV::Form::RegistrationPassword.call(
      password: '@3Fs^1HfaF$2',
      password_confirmation: 'different-secret'
    )

    _(result.success?).must_equal false
    _(LockedCV::Form.validation_errors(result)[:password_confirmation]).must_equal 'does not match password'
  end

  it 'allows unicode profile names and validates birthday format' do
    result = LockedCV::Form::AccountProfile.call(
      email: 'ada@example.com',
      first_name: '愛達',
      last_name: 'Lovelace',
      birthday: '1815-12-10'
    )

    _(result.success?).must_equal true
  end

  it 'rejects invalid profile birthdays' do
    result = LockedCV::Form::AccountProfile.call(
      email: 'ada@example.com',
      birthday: '1815-99-99'
    )

    _(result.success?).must_equal false
    _(LockedCV::Form.validation_errors(result)[:birthday]).must_equal 'must use YYYY-MM-DD format'
  end

  it 'validates change password input' do
    result = LockedCV::Form::ChangePassword.call(
      current_password: 'old-secret',
      password: '@3Fs^1HfaF$2',
      password_confirmation: '@3Fs^1HfaF$2'
    )

    _(result.success?).must_equal true
  end

  it 'validates assign system role input' do
    result = LockedCV::Form::AssignSystemRole.call(username: 'ada-lovelace', role: 'admin')

    _(result.success?).must_equal true
  end

  it 'rejects unknown system roles' do
    result = LockedCV::Form::AssignSystemRole.call(username: 'ada-lovelace', role: 'owner')

    _(result.success?).must_equal false
    _(LockedCV::Form.validation_errors(result)[:role]).must_equal 'must be a known system role'
  end

  it 'validates PDF upload input' do
    pdf = Tempfile.new(['lockedcv-form-upload', '.pdf'])
    pdf.write('%PDF-1.4')
    pdf.rewind

    result = LockedCV::Form::UploadAttachment.call(
      cv: { filename: 'resume.pdf', tempfile: pdf }
    )

    _(result.success?).must_equal true
  ensure
    pdf&.close!
  end

  it 'rejects non-PDF upload filenames' do
    upload = { filename: 'resume.txt', tempfile: Tempfile.new('lockedcv-form-upload') }

    result = LockedCV::Form::UploadAttachment.call(cv: upload)

    _(result.success?).must_equal false
    _(LockedCV::Form.validation_errors(result)[:cv]).must_equal 'must be a PDF file'
  ensure
    upload[:tempfile]&.close!
  end
end
