# frozen_string_literal: true

require 'roda'
require_relative 'app'

module LockedCV
  # Read-only views for files shared with the current account.
  class App < Roda
    route('shared') do |routing|
      require_login!(routing)

      routing.on 'masked-attachments', String do |attachment_id|
        routing.on String do |masked_attachment_id|
          routing.on 'pdf' do
            # GET /shared/masked-attachments/[attachment_id]/[masked_attachment_id]/pdf
            routing.get do
              view_shared_masked_pdf(routing, attachment_id, masked_attachment_id)
            end
          end

          # GET /shared/masked-attachments/[attachment_id]/[masked_attachment_id]
          routing.get do
            view :shared_masked_attachment,
                 locals: {
                   current_account: @current_account,
                   attachment_id:,
                   masked_attachment_id:
                 }
          end
        end
      end

      # GET /shared
      routing.get do
        shared_masked_attachments = list_shared_masked_attachments
        view :shared_attachments,
             locals: {
               current_account: @current_account,
               shared_masked_attachments:
             }
      end
    end

    private

    def list_shared_masked_attachments
      ListSharedMaskedAttachments.new(App.config, current_account: @current_account).call
    rescue ListSharedMaskedAttachments::ServiceUnavailableError => e
      App.logger.warn "SHARED MASKED PDFS UNAVAILABLE: #{e.inspect}"
      []
    end

    def view_shared_masked_pdf(routing, attachment_id, masked_attachment_id)
      pdf_body = ViewMaskedPdf.new(App.config).call(
        attachment_id:,
        masked_attachment_id:,
        auth_token: @current_account.auth_token
      )

      routing.response['Content-Type'] = 'application/pdf'
      routing.response['Content-Disposition'] = 'inline; filename="shared_masked_attachment.pdf"'
      pdf_body
    rescue ViewMaskedPdf::NotFoundError
      preview_failed(routing, 'Shared masked PDF not found', 404)
    rescue ViewMaskedPdf::UnauthorizedError
      preview_failed(routing, 'Please log in again before viewing', 401)
    rescue ViewMaskedPdf::ServiceUnavailableError => e
      App.logger.error "SHARED MASKED PDF VIEW FAILED: #{e.inspect}"
      preview_failed(routing, 'Could not view shared masked PDF', 502)
    end
  end
end
