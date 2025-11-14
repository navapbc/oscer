# frozen_string_literal: true

class ArrayType < ActiveModel::Type::Value
  attr_reader :of

  def type = :array

  def initialize(of:)
    super()
    @of = of
  end

  def item_types
    ActiveModel::Validations::AttributesTypeValidator.new.get_underlying_types_for_attribute_type(@of)
  end

  private

  def cast_value(value)
    case value
    when Array
      value.map { |item| cast_item(item) }
    else
      nil
    end
  end

  def cast_item(item)
    if item_types.include?(item.class)
      return item
    end

    if @of.respond_to?(:cast)
      return @of.cast(item)
    end

    for t in item_types
      begin
        res = cast_item_type(item, t)
        if !res.nil?
            return res
        end
      rescue
        # continue iteration
      end
    end

    nil
  end

  def cast_item_type(item, item_type)
    case item
    when Hash
      if item_type.respond_to?(:new_filtered)
        item_type.new_filtered(item)
      else
        item_type.new(item)
      end
    when String
      if item_type.respond_to?(:parse)
        item_type.parse(item)
      else
        nil
      end
    else
      nil
    end
  end
end
