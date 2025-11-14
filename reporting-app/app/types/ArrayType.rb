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

    case item
    when Hash
      if @of.respond_to?(:new_filtered)
        @of.new_filtered(item)
      else
        @of.new(item)
      end
    else
      nil
    end
  end
end
