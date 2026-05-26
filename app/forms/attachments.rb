# frozen_string_literal: true

require_relative 'form_base'

module LockedCV
  module Form
    UploadAttachment = Dry::Validation.Contract do
      params do
        required(:cv).filled
      end

      rule(:cv) do
        filename = Form.uploaded_value(value, :filename).to_s
        tempfile = Form.uploaded_value(value, :tempfile)

        if tempfile.nil? || filename.strip.empty?
          key.failure('must include a PDF file')
        elsif !File.extname(filename).casecmp?('.pdf')
          key.failure('must be a PDF file')
        end
      end
    end
  end
end
