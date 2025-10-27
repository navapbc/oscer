# frozen_string_literal: true

# loosely aligned with https://github.com/yez/validates_type
# similar to https://github.com/public-law/validated_object
# similar to Strata::Validations' validate_type_casted_attribute
# TODO: migrate to Strata
#
# Perhaps more ideally each attribute type would expose some logic for testing
# if values match something the underlying class will accept. The existing
# `assert_valid_value` upstream is kinda close, but implementation is
# inconsistent, and it's called during attribute loading/before type casting, so
# errors from it need to be captured differently.
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

        # nothing to check, requiring a value when none was given is a different
        # validation
        if raw_value.nil?
          return
        end

        attr_type = record.class.type_for_attribute(attribute)
        expected_types = get_underlying_types_for_attribute_type(attr_type)

        is_collection = expected_types.count == 1 && expected_types[0] <= Enumerable
        if is_collection
          if !value.is_a?(Enumerable) || !raw_value.is_a?(Enumerable)
            record.errors.add(attribute, "invalid_value")
            return
          end

          if value.count != raw_value.count
            record.errors.add(attribute, "invalid_item_value")
            return
          end

          # TODO: generalize support for this?
          # if the values are supposed to be of a particular type
          if attr_type.respond_to?(:of)
            item_type = attr_type.of
          end
          if attr_type.respond_to?(:item_class)
            item_type = attr_type.item_class
          end

          if item_type.present?
            value.each_with_index do |item, index|
              check_value_for_type(record, attribute + "[#{index}]", item, raw_value[index], get_underlying_types_for_attribute_type(item_type))
            end
          end
        else
          check_value_for_type(record, attribute, value, raw_value, expected_types)
        end
      end

      def check_value_for_type(record, attribute, value, raw_value, expected_types)
        # If model.<attribute> is nil, but model.<attribute>_before_type_cast is
        # not nil, that means the application failed to cast the value to the
        # appropriate type in order to complete the attribute assignment. This
        # means the original value is invalid.
        did_type_cast_fail = value.nil? && !raw_value.nil?
        if did_type_cast_fail
          record.errors.add(attribute, "invalid_value")
          return
        end

        is_expected_type = expected_types.include?(value.class)
        if !is_expected_type && !raw_value.blank?
          record.errors.add(attribute, "invalid_value")
          return
        end

        for expected_type in expected_types
          # don't let any old value just come through as a string
          # TODO: create better/more strict ActiveModel::Type::String class that avoids this natively
          if expected_type == String && !raw_value.nil? && !raw_value.is_a?(String)
            record.errors.add(attribute, "invalid_value")
            return
          end

          # don't let non-numeric strings masquerade as a proper number
          # TODO: create better/more strict ActiveModel::Type::Integer class that avoids this natively
          if expected_type == Integer && !raw_value.nil?
            non_numeric_string = value.zero? && (raw_value != "0" || raw_value != 0)
            boolean = (raw_value.is_a?(TrueClass) || raw_value.is_a?(FalseClass))

            if non_numeric_string || boolean
              record.errors.add(attribute, "invalid_value")
            end
          end

          # don't let random input map to a proper boolean
          # TODO: create better/more strict ActiveModel::Type::Boolean class that avoids this natively
          if (expected_type == TrueClass || expected_type == FalseClass) && !raw_value.nil?
            false_values = ActiveModel::Type::Boolean::FALSE_VALUES
            true_values = [
              true, 1,
              "1", :"1",
              "t", :t,
              "T", :T,
              "true", :true,
              "TRUE", :TRUE,
              "on", :on,
              "off", :off
            ].to_set.freeze

            if !(false_values|true_values).include?(raw_value)
              record.errors.add(attribute, "invalid_value")
            end
          end
        end
      end

      def get_underlying_types_for_attribute_type(attr_type)
        if attr_type.respond_to?(:underlying_types)
          return attr_type.underlying_types
        end

        # TODO: Could more flexibly do attr_type.respond_to?(:type), but that's
        # kinda generic
        if attr_type.is_a?(ActiveModel::Type::Value)
          symbol = attr_type.type()
        end

        # all ActiveModel::Type::Value instances _should_ respond with something
        # for the symbol, but some things don't, like Strata:Attributes
        #
        # TODO: have Strata::Attributes list their type at the standard `type`
        # or some other mechanism?
        if symbol.blank?
          case attr_type
          when Strata::Attributes::ArrayAttribute::ArrayType
            symbol = :array
          else
            raise TypeError, "Unknown attribute type class: #{attr_type.class}"
          end
        end

        if !symbol.is_a?(Symbol)
          raise TypeError, "Unknown attribute type parameter: #{attr_type}"
        end

        if symbol == :boolean
          return [ TrueClass, FalseClass ]
        end

        [ symbol_class(symbol) ]
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
