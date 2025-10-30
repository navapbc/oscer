# frozen_string_literal: true

class EnumType < ActiveModel::Type::Value
  def type = :enum

  def initialize(options:, raise_on_invalid_values: false)
    super()

    @_raise_on_invalid_values = raise_on_invalid_values

    case options
    when Hash
        @options = options.keys
    when Array
        @options = options
    else
      raise ArgumentError, "Enum attribute options must be a hash or array."
    end
  end

  def assert_valid_value(value)
    return unless @_raise_on_invalid_values

    value.blank? or @options.include?(value) or
      raise ArgumentError, "#{value.inspect} is not valid. Expected one of: #{@options}"
  end

  # TODO: possibly rename to valid_values? Should that include nil?
  def options
    @options
  end
end
