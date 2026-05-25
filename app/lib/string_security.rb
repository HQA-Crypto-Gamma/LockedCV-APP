# frozen_string_literal: true

module LockedCV
  # String scoring helpers for lightweight form validation.
  module StringSecurity
    module_function

    def entropy(value)
      text = value.to_s
      return 0.0 if text.empty?

      counts = text.each_char.tally
      length = text.length.to_f
      counts.values.sum do |count|
        probability = count / length
        -probability * Math.log2(probability)
      end
    end
  end
end
