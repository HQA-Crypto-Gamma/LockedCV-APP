# frozen_string_literal: true

require 'http'
require 'http/form_data'
require 'json'
require 'uri'

module LockedCV
  # Shared helper for HTTP calls to LockedCV-API
  class ApiClient
    # Wraps a non-2xx API response with parsed body for callers
    class ApiError < StandardError
      attr_reader :status, :body

      def initialize(status, body)
        @status = status
        @body = body
        super(body.is_a?(Hash) ? body['message'].to_s : body.to_s)
      end
    end

    def initialize(config)
      @config = config
    end

    def post(path, body, auth_token: nil)
      parse(http(auth_token).post(url(path), json: body))
    end

    def post_multipart(path, fields, auth_token: nil)
      parse(http(auth_token).post(url(path), form: fields))
    end

    def put(path, body = {}, auth_token: nil)
      parse(http(auth_token).put(url(path), json: body))
    end

    def delete(path, body = nil, auth_token: nil)
      request = http(auth_token).headers('Content-Type' => 'application/json')
      response = body ? request.delete(url(path), body: body.to_json) : request.delete(url(path))
      parse(response)
    end

    def get(path, params: {}, auth_token: nil)
      parse(http(auth_token).get(url_with_params(path, params)))
    end

    def self.attributes_from(response)
      response.fetch('data').fetch('data').fetch('attributes')
    end

    def self.error_details(error)
      [error.class, error.message].compact.join(': ')
    end

    private

    def http(auth_token)
      auth_token ? HTTP.auth("Bearer #{auth_token}") : HTTP
    end

    def url(path)
      "#{@config.API_URL}#{path}"
    end

    def url_with_params(path, params)
      return url(path) if params.empty?

      "#{url(path)}?#{URI.encode_www_form(params)}"
    end

    def parse(response)
      raw = response.body.to_s
      parsed = raw.empty? ? {} : JSON.parse(raw)
      raise ApiError.new(response.code, parsed) unless (200..299).cover?(response.code)

      parsed
    end
  end
end
