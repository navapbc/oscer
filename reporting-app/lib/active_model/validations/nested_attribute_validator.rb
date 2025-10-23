# frozen_string_literal: true

# similar to Strata::Validations.strata_validates_nested
# TODO: migrate to Strata
module ActiveModel
  module Validations
    class AttributeValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        if value
          if value.is_a?(Enumerable)
            value.each_with_index do |item, index|
              validate_value(record, attribute, attribute + "[#{index}]", item)
            end
          else
            validate_value(record, attribute, attribute, value)
          end
        end
      end

      private

      def validate_value(record, attribute, attribute_name_for_error, value)
        # Related https://linear.app/nava-platform/issue/TSS-147/handle-validation-of-native-ruby-objects-in-array-class
        if value.respond_to?(:invalid?) && value.invalid?
          value.errors.each do |error|
            if error.attribute == :base
              attr_name = attribute_name_for_error
              err_options = {}
            else
              attr_name = "#{attribute_name_for_error}.#{error.attribute}"
              err_options = error.options
            end

            # TODO: dedupe message here?
            record.errors.import(error, { attribute: attr_name })
          end
        end
      end
    end

    class NestedAttributeValidator < ActiveModel::Validator
      def validate(record)
        if !record.attributes.empty?
          AttributeValidator.new(options.merge({ attributes: record.attributes.keys })).validate(record)
        end
      end
    end
  end
end
