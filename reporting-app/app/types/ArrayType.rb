# frozen_string_literal: true

class ArrayType < ActiveModel::Type::Value
  def type = :array

  def initialize(of:)
    super()
    @of = of
  end

  private

  def cast_value(value)
    parsed_array = []

    for item in value
      parsed_array.push(@of.cast(item))
    end

    parsed_array
  end
end
