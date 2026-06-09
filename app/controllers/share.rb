# frozen_string_literal: true

require 'roda'
require_relative 'app'

module LockedCV
  # Routes for opening share links in the web app.
  class App < Roda
    route('share') do |routing|
      routing.on 'masked-attachments', String do |token|
        # GET /share/masked-attachments/[token]
        routing.get do
          redeem_masked_attachment_share_link(routing, token)
        end
      end
    end

    private

    def redeem_masked_attachment_share_link(routing, token)
      unless @current_account.logged_in?
        session['post_login_redirect'] = "/share/masked-attachments/#{token}"
        flash[:error] = 'Please log in to open this shared masked PDF'
        routing.redirect '/#login-modal'
      end

      redemption = RedeemMaskedAttachmentShareLink.new(App.config).call(
        token:,
        auth_token: @current_account.auth_token
      )
      attachment_id = redemption.fetch('attachment_id')
      masked_attachment_id = redemption.fetch('masked_attachment_id')

      flash[:notice] = 'Shared masked PDF added to your vault'
      routing.redirect "/shared/masked-attachments/#{attachment_id}/#{masked_attachment_id}"
    rescue RedeemMaskedAttachmentShareLink::NotFoundError => e
      App.logger.warn "MASKED PDF SHARE LINK NOT FOUND: #{e.inspect}"
      flash[:error] = 'Share link is invalid or expired'
      routing.redirect '/'
    rescue RedeemMaskedAttachmentShareLink::UnauthorizedError => e
      App.logger.warn "MASKED PDF SHARE LINK UNAUTHORIZED: #{e.inspect}"
      flash[:error] = 'Please log in again to open this shared masked PDF'
      routing.redirect '/#login-modal'
    rescue RedeemMaskedAttachmentShareLink::ServiceUnavailableError => e
      App.logger.error "MASKED PDF SHARE LINK REDEEM FAILED: #{e.inspect}"
      flash[:error] = 'Could not open this shared masked PDF'
      routing.redirect '/'
    end
  end
end
