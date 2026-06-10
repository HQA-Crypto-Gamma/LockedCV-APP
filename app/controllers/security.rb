# frozen_string_literal: true

require 'json'
require 'roda'
require_relative 'app'

module LockedCV
  # Browser security headers and report-only endpoints for the web app.
  class App < Roda
    module BrowserSecurity
      module_function

      def apply_headers(response)
        headers = response.is_a?(Array) ? (response[1] ||= {}) : response
        return unless headers

        pdf_response = pdf_response?(headers)

        headers['X-Frame-Options'] = pdf_response ? 'SAMEORIGIN' : 'DENY'
        headers['X-Content-Type-Options'] = 'nosniff'
        headers['X-XSS-Protection'] = '1; mode=block'
        headers['X-Permitted-Cross-Domain-Policies'] = 'none'
        headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
        headers['Permissions-Policy'] = permissions_policy
        headers['Content-Security-Policy'] = content_security_policy(pdf_response:)
      end

      def content_security_policy(pdf_response: false)
        [
          "default-src 'self'",
          "base-uri 'self'",
          "object-src 'none'",
          pdf_response ? "frame-ancestors 'self'" : "frame-ancestors 'none'",
          "form-action 'self'",
          "img-src 'self' data:",
          "font-src 'self'",
          "connect-src 'self'",
          "frame-src 'self' blob:",
          "script-src 'self'",
          "style-src 'self'",
          'report-uri /security/report_csp_violation'
        ].join('; ')
      end

      def pdf_response?(headers)
        headers.fetch('Content-Type', '').to_s.include?('application/pdf')
      end

      def permissions_policy
        [
          'camera=()',
          'microphone=()',
          'geolocation=()',
          'payment=()'
        ].join(', ')
      end
    end

    route('security') do |routing|
      routing.on 'report_csp_violation' do
        # POST /security/report_csp_violation
        routing.post do
          log_csp_violation(routing)
          routing.response.status = 204
          ''
        end
      end
    end

    private

    def log_csp_violation(routing)
      raw_body = routing.body.read.to_s
      return if raw_body.empty?

      App.logger.warn "CSP VIOLATION: #{JSON.parse(raw_body)}"
    rescue JSON::ParserError
      App.logger.warn "CSP VIOLATION: #{raw_body}"
    end
  end
end
