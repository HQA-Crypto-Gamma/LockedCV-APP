# frozen_string_literal: true

module LockedCV
  # Uploads a CV attachment through LockedCV-API.
  class UploadAttachment
    class ValidationError < StandardError; end
    class UnauthorizedError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(auth_token:, uploaded_file:)
      ensure_upload_present!(uploaded_file)

      upload_response(auth_token:, uploaded_file:)
        .fetch('data').fetch('data').fetch('attributes')
    rescue ApiClient::ApiError => e
      raise api_error_for(e)
    rescue HTTP::Error, JSON::ParserError => e
      raise unavailable_error_for(e)
    end

    private

    def upload_response(auth_token:, uploaded_file:)
      @client.post_multipart(
        '/attachments/upload',
        {
          file: multipart_file(uploaded_file),
          original_filename: uploaded_value(uploaded_file, :filename)
        },
        auth_token:
      )
    end

    def ensure_upload_present!(uploaded_file)
      tempfile = uploaded_value(uploaded_file, :tempfile)
      filename = uploaded_value(uploaded_file, :filename)
      raise ValidationError, 'Please choose a PDF file to upload' if tempfile.nil? || filename.to_s.strip.empty?
    end

    def multipart_file(uploaded_file)
      HTTP::FormData::File.new(
        uploaded_value(uploaded_file, :tempfile),
        filename: uploaded_value(uploaded_file, :filename),
        content_type: uploaded_value(uploaded_file, :type) || 'application/pdf'
      )
    end

    def uploaded_value(uploaded_file, key)
      return uploaded_file[key] if uploaded_file.respond_to?(:key?) && uploaded_file.key?(key)
      return uploaded_file[key.to_s] if uploaded_file.respond_to?(:key?) && uploaded_file.key?(key.to_s)

      nil
    end

    def api_error_for(error)
      case error.status
      when 400
        ValidationError.new(error.message.empty? ? 'Could not upload attachment' : error.message)
      when 401, 403
        UnauthorizedError.new(error.message)
      else
        unavailable_error_for(error)
      end
    end

    def unavailable_error_for(error)
      ServiceUnavailableError.new("Attachment upload API unavailable: #{error.message}")
    end
  end
end
