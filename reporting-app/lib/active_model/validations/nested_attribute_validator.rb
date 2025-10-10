# frozen_string_literal: true

module ActiveModel
    module Validations
      class AttributeValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          if value && value.respond_to?(:invalid?) && value.invalid?
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
        end
      end
    end
end
