# frozen_string_literal: true

require 'http'
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

    def post(path, body)
      parse(HTTP.post(url(path), json: body))
    end

    def put(path, body)
      parse(HTTP.put(url(path), json: body))
    end

    def delete(path, body = {})
      parse(HTTP.delete(url(path), json: body))
    end

    def get(path, params = {})
      parse(HTTP.get(url_with_params(path, params)))
    end

    private

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
