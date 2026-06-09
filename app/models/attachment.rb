# frozen_string_literal: true

module LockedCV
  # APP-side attachment wrapper built from one API list entry.
  class Attachment
    attr_reader :attributes, :policy

    def initialize(api_entry)
      @attributes = api_entry.fetch('data').fetch('attributes')
      @policy = api_entry.fetch('policy', {})
    end

    def id
      attributes['id']
    end

    def attachment_name
      attributes['attachment_name']
    end

    def masked_attachments_count
      attributes.fetch('masked_attachments_count', 0).to_i
    end

    def masked_versions?
      masked_attachments_count.positive?
    end

    def created_at
      attributes['created_at']
    end

    def uploaded_at
      created_at || '-'
    end

    def role
      policy['role']
    end

    def owner?
      role == 'owner'
    end

    def viewer_masked?
      role == 'viewer_masked'
    end

    def can_view?
      policy['can_view'] == true
    end

    def can_view_masked?
      policy['can_view_masked'] == true
    end

    def can_delete?
      policy['can_delete'] == true
    end
  end
end
