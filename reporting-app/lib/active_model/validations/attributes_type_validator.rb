# frozen_string_literal: true

# similar to https://github.com/yez/validates_type
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
      STANDARD_TYPE_SYMBOL_CLASS = {
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
      }.freeze

      STRATA_TYPE_SYMBOL_CLASS = {
        date_from_hash: Date,
        money: Strata::Money,
        us_date: Strata::USDate,
        tax_id: Strata::TaxId
      }.freeze

      TYPE_SYMBOL_CLASS = STANDARD_TYPE_SYMBOL_CLASS.merge(STRATA_TYPE_SYMBOL_CLASS).freeze

      def validate(record)
        if record.attributes.empty?
          return
        end

        attributes = record.attributes.keys

        attributes.each do |attribute_name|
          value = record.read_attribute_for_validation(attribute_name)

          check_attr_type(record, attribute_name, value)

          # TODO: handle allow_nil/allow_blank???
          # next if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
        end
      end

      private

      def check_attr_type(record, attribute_name, value)
        raw_value = record.read_attribute_before_type_cast(attribute_name)

        # nothing to check, requiring a value when none was given is a different
        # validation at the moment
        #
        # TODO: move presence: true check into this validator, or provide an
        # alternate checker that looks for before type cast value to determine
        # "presence", or post-process the errors and remove and "blank" types
        # if the same field has an :invalid_value
        if raw_value.nil?
          return
        end

        attr_type = record.class.type_for_attribute(attribute_name)
        expected_value_types = get_underlying_types_for_attribute_type(attr_type)

        check_value_for_types(
          record,
          record.errors,
          { name: attribute_name, type: attr_type },
          { final: value, raw: raw_value },
          expected_value_types
        )
      end

      def check_value_for_types(record, errors, attr_info, value_info, expected_types)
        type_errors = {}
        for expected_type in expected_types
          # TODO: is the record the correct base to use?
          errs = ActiveModel::Errors.new(record)
          type_errors[expected_type.to_s] = errs

          check_value_for_type(record, errs, attr_info, value_info, expected_type)
        end

        types_with_errors = type_errors.reject { |key, value| value.empty? }
        # if every type had errors, that means there was no valid value, so add
        # the errors
        if types_with_errors.size == expected_types.count
          types_with_errors.each_value do |type_errors|
            type_errors.each do |error|
              errors.import(error) unless errors.added?(error.attribute, error.type)
            end
          end
        end
      end

      def check_value_for_type(record, errors, attr_info, value_info, expected_type)
        if expected_type <= Enumerable
          if !value_info[:final].is_a?(Enumerable) || !value_info[:raw].is_a?(Enumerable)
            errors.add(attr_info[:name], :invalid_value)
            return
          end

          if value_info[:final].count != value_info[:raw].count
            # TODO: should this be a separate error type?
            errors.add(attr_info[:name], "invalid_item_value")
            return
          end

          # TODO: generalize support for this?
          # if the values are supposed to be of a particular type
          if attr_info[:type].respond_to?(:of)
            item_type = attr_info[:type].of
          end
          if attr_info[:type].respond_to?(:item_class)
            item_type = attr_info[:type].item_class
          end

          if item_type.present?
            value_info[:final].each_with_index do |item, index|
              check_value_for_types(
                record,
                errors,
                attr_info.merge({ name: attr_info[:name] + "[#{index}]" }),
                { final: item, raw: value_info[:raw][index] },
                get_underlying_types_for_attribute_type(item_type)
              )
            end
          end
        else
          check_value_for_type_item(record, errors, attr_info, value_info, expected_type)
        end
      end

      def check_value_for_type_item(record, errors, attr_info, value_info, expected_type)
        # If model.<attribute> is nil, but model.<attribute>_before_type_cast is
        # not nil, that means the application failed to cast the value to the
        # appropriate type in order to complete the attribute assignment. This
        # means the original value is invalid.
        did_type_cast_fail = value_info[:final].nil? && !value_info[:raw].nil?
        if did_type_cast_fail
          errors.add(attr_info[:name], :invalid_value)
          return
        end

        is_expected_type = value_info[:final].is_a?(expected_type)
        if !is_expected_type && !value_info[:raw].blank?
          errors.add(attr_info[:name], :invalid_value)
          return
        end

        # don't let any old value just come through as a string
        # TODO: create better/more strict ActiveModel::Type::String class that avoids this natively
        if expected_type == String && !value_info[:raw].nil? && !value_info[:raw].is_a?(String)
          errors.add(attr_info[:name], :invalid_value)
          return
        end

        # don't let non-numeric strings masquerade as a proper number
        # TODO: create better/more strict ActiveModel::Type::Integer class that avoids this natively
        if expected_type == Integer && !value_info[:raw].nil?
          non_numeric_string = value_info[:final].zero? && (value_info[:raw] != "0" || value_info[:raw] != 0)
          boolean = (value_info[:raw].is_a?(TrueClass) || value_info[:raw].is_a?(FalseClass))

          if non_numeric_string || boolean
            errors.add(attr_info[:name], :invalid_value)
          end
        end

        # don't let random input map to a proper boolean
        # TODO: create better/more strict ActiveModel::Type::Boolean class that avoids this natively
        if (expected_type == TrueClass || expected_type == FalseClass) && !value_info[:raw].nil?
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

          if !(false_values|true_values).include?(value_info[:raw])
            errors.add(attr_info[:name], :invalid_value)
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
        # for the symbol, but some things don't, like some Strata:Attributes
        #
        # TODO: have Strata::Attributes list their type at the standard `type`
        # or some other mechanism? We could have additional convention/fallback
        # logic that strips `Type` off the end and uses that for a lookup
        # (either here or more likely as a part of some default logic in
        # Strata::Attribute types)? Feels like a lot of layered conventions that
        # are a little hard to grok though...
        if symbol.blank?
          case attr_type
          when Strata::Attributes::ArrayAttribute::ArrayType
            symbol = :array
          when Strata::Attributes::YearMonthAttribute::YearMonthType
            symbol = :year_month
            # TODO: could also just return directly, but potentially less upstreamable
            # return [ Strata::YearMonth ]
          when Strata::Attributes::YearQuarterAttribute::YearQuarterType
            symbol = :year_quarter
            # TODO: could also just return directly, but potentially less upstreamable
            # return [ Strata::YearQuarter ]
          else
            # might have been given a direct class for the values instead of an
            # attribute type, so just return that if so
            #
            # TODO: make this cleaner? this is mostly for array/collection types
            # when we want to check their item types, which may be the
            # underlying type themselves, but there may be other cases like
            # that?
            if attr_type.is_a?(Class)
              return [ attr_type ]
            end
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
        begin
          # TODO: wonder if `resolve_class` could be named better or live
          # somewhere else? Though there may be less generic logic in the future
          # around "resolving" the "class" for "attributes", where the current
          # location makes sense.
          return Strata::Attributes.resolve_class(symbol)
        rescue NameError
          # continue to fallback logic
        end

        TYPE_SYMBOL_CLASS[symbol] || fail(TypeError, "Unknown type symbol: #{symbol}")
      end
    end
  end
end
