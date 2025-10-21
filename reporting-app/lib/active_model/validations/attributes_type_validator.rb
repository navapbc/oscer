# frozen_string_literal: true

# loosely aligned with https://github.com/yez/validates_type
# similar to https://github.com/public-law/validated_object
# similar to Strata::Validations' validate_type_casted_attribute
module ActiveModel
  module Validations
    class AttributesTypeValidator < ActiveModel::Validator
      def validate(record)
        if record.attributes.empty?
          return
        end

        attributes = record.attributes.keys

        attributes.each do |attribute|
          value = record.read_attribute_for_validation(attribute)

          check_type(record, attribute, value)

          # TODO: handle allow_nil/allow_blank???
          # next if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
        end
      end

      private

      def check_type(record, attribute, value)
        raw_value = record.read_attribute_before_type_cast(attribute)

        attr_type = record.class.type_for_attribute(attribute)
        expected_type = get_underlying_type_of_attribute_type(attr_type)

        if expected_type <= Enumerable
          if !value.is_a?(Enumerable) || !raw_value.is_a?(Enumerable)
            record.errors.add(attribute, "invalid_value")
            return
          end

          if value.count != raw_value.count
            record.errors.add(attribute, "invalid_item_value")
            return
          end

          # if the values are supposed to be of a particular type
          if attr_type.respond_to?(:of)
            item_type = attr_type.of
          end
          if attr_type.respond_to?(:item_class)
            item_type = attr_type.item_class
          end

          if item_type.present?
            value.each_with_index do |item, index|
              check_value_for_type(record, attribute + "[#{index}]", item, raw_value[index], get_underlying_type_of_attribute_type(item_type))
            end
          end
        else
          check_value_for_type(record, attribute, value, raw_value, expected_type)
        end
      end

      def check_value_for_type(record, attribute, value, raw_value, expected_type)
        # If model.<attribute> is nil, but model.<attribute>_before_type_cast is
        # not nil, that means the application failed to cast the value to the
        # appropriate type in order to complete the attribute assignment. This
        # means the original value is invalid.
        did_type_cast_fail = value.nil? && !raw_value.nil?
        if did_type_cast_fail
          record.errors.add(attribute, "invalid_value")
          return
        end

        is_expected_type = expected_type.respond_to?(:is_valid_type) ? expected_type.is_valid_type(value) : value.is_a?(expected_type)
        if !is_expected_type && !raw_value.blank?
          record.errors.add(attribute, "invalid_value")
          return
        end

        # don't let any old value just come through as a string
        # TODO: create better/more strict ActiveModel::Type::String class that avoids this natively
        if expected_type == String && !raw_value.nil? && !raw_value.is_a?(String)
          record.errors.add(attribute, "invalid_value")
          return
        end

        # don't let non-numeric strings masquerade as a proper number
        # TODO: create better/more strict ActiveModel::Type::Integer class that avoids this natively
        if expected_type == Integer && !raw_value.nil? && value.zero? && (raw_value != "0" || raw_value != 0)
          record.errors.add(attribute, "invalid_value")
        end
      end

      def get_underlying_type_of_attribute_type(attr_type)
        if attr_type.respond_to?(:underlying_type)
          return attr_type.underlying_type
        end

        symbol = attr_type.respond_to?(:type) ? attr_type.type : attr_type

        if symbol == :boolean
          # TODO: handle this
        end

        symbol_class(symbol)
      end

      def symbol_class(symbol)
        {
          array: Array,
          float: Float,
          hash: Hash,
          integer: Integer,
          string: String,
          symbol: Symbol,
          time: Time,
          date: Date,
          decimal: BigDecimal,
          big_decimal: BigDecimal
        }[symbol] || fail(TypeError, "Unsupported type #{ symbol.to_s.camelize } given")
      end
    end
  end
end
