# frozen_string_literal: true

module LockedCV
  # APP-side masked attachment wrapper built from one API version entry.
  class MaskedAttachment
    attr_reader :attributes

    def initialize(api_entry)
      @attributes = api_entry.fetch('data').fetch('attributes')
    end

    def id
      attributes['id']
    end

    def attachment_id
      attributes['attachment_id']
    end

    def attachment_name
      attributes['attachment_name']
    end

    def masked_items_count
      attributes.fetch('masked_items_count', 0).to_i
    end

    def created_at
      attributes['created_at']
    end
  end
end
