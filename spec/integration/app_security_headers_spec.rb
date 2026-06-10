# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Browser security protections' do
  it 'sets browser security headers on app responses' do
    get '/'

    _(last_response.status).must_equal 200
    _(last_response.headers['X-Frame-Options']).must_equal 'DENY'
    _(last_response.headers['X-Content-Type-Options']).must_equal 'nosniff'
    _(last_response.headers['X-Permitted-Cross-Domain-Policies']).must_equal 'none'
    _(last_response.headers['Referrer-Policy']).must_equal 'strict-origin-when-cross-origin'
    _(last_response.headers['Permissions-Policy']).must_include 'camera=()'

    csp = last_response.headers['Content-Security-Policy']
    _(csp).must_include "default-src 'self'"
    _(csp).must_include "frame-ancestors 'none'"
    _(csp).must_include "object-src 'none'"
    _(csp).must_include 'report-uri /security/report_csp_violation'
    _(csp).wont_include "'unsafe-inline'"
  end

  it 'accepts CSP violation reports' do
    post '/security/report_csp_violation',
         { 'csp-report' => { 'blocked-uri' => 'https://evil.example/script.js' } }.to_json,
         'CONTENT_TYPE' => 'application/csp-report'

    _(last_response.status).must_equal 204
  end
end
