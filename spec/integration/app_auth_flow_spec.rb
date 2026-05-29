# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Authentication flow' do
  after do
    WebMock.reset!
  end

  it 'BAD: rejects blank login form without calling the API' do
    post '/auth/login', username: '', password: ''

    _(last_response.status).must_equal 302
    _(last_response.location).must_match %r{/\z}
    assert_not_requested(:post, "#{API_URL}/auth/authenticate")
  end
end
