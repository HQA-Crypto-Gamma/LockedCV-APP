# frozen_string_literal: true

module LockedCV
  # APP-side wrapper for attachment masking preview results.
  class ScanResult
    attr_reader :attributes

    def initialize(attributes)
      @attributes = attributes || {}
    end

    def attachment_id
      attributes['attachment_id']
    end

    def masked_text
      attributes['masked_text'].to_s
    end

    def matches
      Array(attributes['matches'])
    end

    def match_count
      matches.length
    end

    def empty?
      matches.empty?
    end
  end
end
