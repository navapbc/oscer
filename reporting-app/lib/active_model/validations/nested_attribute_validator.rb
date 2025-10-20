# frozen_string_literal: true

module ActiveModel
    module Validations
      class AttributeValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          if value
            if value.is_a?(Enumerable)
              value.each_with_index do |item, index|
                validate_value(record, attribute + "[#{index}]", value)
              end
            else
              validate_value(record, attribute, value)
            end
          end
        end

        private

        def validate_value(record, attribute, value)
          if value.respond_to?(:invalid?) && value.invalid?
            value.errors.each do |error|
              if error.attribute == :base
                record.errors.add(name, error.type)
              else
                record.errors.add("#{attribute}.#{error.attribute}", error.type, **error.options)
              end
            end
          end
        end
      end

      class NestedAttributeValidator < ActiveModel::Validator
        def validate(record)
          AttributeValidator.new(options.merge({ attributes: record.attributes.keys })).validate(record)
          if !record.attributes.empty?
            AttributeValidator.new(options.merge({ attributes: record.attributes.keys })).validate(record)
          end
        end
      end
    end
end
