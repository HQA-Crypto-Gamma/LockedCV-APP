# frozen_string_literal: true

require 'roda'
require_relative 'app'

module LockedCV
  # Attachment routes for the LockedCV Web App
  class App < Roda
    route('attachments') do |routing|
      require_login!(routing)

      routing.on 'upload' do
        # POST /attachments/upload
        routing.post do
          upload_current_account_attachment(routing)
        end
      end

      routing.on String do |attachment_id|
        routing.on 'scan' do
          # GET /attachments/[attachment_id]/scan
          routing.get do
            show_attachment_scan(routing, attachment_id)
          end
        end

        routing.on 'delete' do
          # POST /attachments/[attachment_id]/delete
          routing.post do
            delete_current_account_attachment(routing, attachment_id)
          end
        end
      end
    end

    private

    def upload_current_account_attachment(routing)
      attachment = upload_selected_attachment(routing)

      flash[:notice] = 'CV uploaded successfully'
      routing.redirect "/attachments/#{attachment.fetch('id')}/scan"
    rescue FormValidationError => e
      upload_form_failed(routing, e)
    rescue KeyError => e
      upload_failed(routing, e, 'Attachment upload returned an invalid response', :error)
    rescue UploadAttachment::ValidationError => e
      upload_failed(routing, e, e.message, :warn)
    rescue UploadAttachment::UnauthorizedError => e
      upload_failed(routing, e, 'Please log in again before uploading', :warn, '/#login-modal')
    rescue UploadAttachment::ServiceUnavailableError => e
      upload_failed(routing, e, 'Attachment upload is temporarily unavailable', :error)
    end

    def upload_selected_attachment(routing)
      form_data = validate_form(Form::UploadAttachment, routing.params)
      UploadAttachment.new(App.config).call(
        auth_token: @current_account.auth_token,
        uploaded_file: form_data[:cv]
      )
    end

    def show_attachment_scan(routing, attachment_id)
      scan_result = GetMaskedAttachmentText.new(App.config).call(
        attachment_id:,
        auth_token: @current_account.auth_token
      )

      view :attachment_scan,
           locals: {
             current_account: @current_account,
             scan_result:
           }
    rescue GetMaskedAttachmentText::NotFoundError => e
      scan_failed(routing, e, 'Attachment not found', :warn)
    rescue GetMaskedAttachmentText::UnauthorizedError => e
      scan_failed(routing, e, 'Please log in again before scanning', :warn, '/#login-modal')
    rescue GetMaskedAttachmentText::ServiceUnavailableError => e
      scan_failed(routing, e, 'Attachment scan is temporarily unavailable', :error)
    end

    def scan_failed(routing, error, message, level, destination = '/')
      App.logger.public_send(level, "ATTACHMENT SCAN FAILED: #{error.inspect}")
      flash[:error] = message
      routing.redirect destination
    end

    def upload_failed(routing, error, message, level, destination = '/')
      App.logger.public_send(level, "ATTACHMENT UPLOAD FAILED: #{error.inspect}")
      flash[:error] = message
      routing.redirect destination
    end

    def upload_form_failed(routing, error)
      App.logger.warn "ATTACHMENT UPLOAD INVALID: #{error.inspect}"
      flash[:error] = error.message
      routing.redirect '/'
    end

    def delete_current_account_attachment(routing, attachment_id)
      delete_selected_attachment(attachment_id)

      flash[:notice] = 'Attachment deleted'
      routing.redirect '/'
    rescue DeleteAttachment::NotFoundError => e
      delete_failed(routing, e, 'Attachment not found', :warn)
    rescue DeleteAttachment::UnauthorizedError => e
      delete_failed(routing, e, 'Please log in again before deleting', :warn, '/#login-modal')
    rescue DeleteAttachment::ServiceUnavailableError => e
      delete_failed(routing, e, 'Attachment delete is temporarily unavailable', :error)
    end

    def delete_selected_attachment(attachment_id)
      DeleteAttachment.new(App.config).call(
        attachment_id:,
        auth_token: @current_account.auth_token
      )
    end

    def delete_failed(routing, error, message, level, destination = '/')
      App.logger.public_send(level, "ATTACHMENT DELETE FAILED: #{error.inspect}")
      flash[:error] = message
      routing.redirect destination
    end
  end
end
