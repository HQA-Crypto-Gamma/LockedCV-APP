# frozen_string_literal: true

module LockedCV
  # APP-side wrapper for one masked PDF shared with the current account.
  class SharedMaskedAttachment
    attr_reader :attributes

    def initialize(api_entry)
      @attributes = api_entry.fetch('data').fetch('attributes')
    end

    def attachment_id
      attributes['attachment_id']
    end

    def masked_attachment_id
      attributes['masked_attachment_id']
    end

    def attachment_name
      attributes['attachment_name']
    end

    def masked_attachment_name
      attributes['masked_attachment_name']
    end

    def display_name
      masked_attachment_name || attachment_name
    end

    def masked_items_count
      attributes.fetch('masked_items_count', 0).to_i
    end

    def shared_at
      attributes['shared_at'] || attributes['created_at'] || '-'
    end
  end
end
