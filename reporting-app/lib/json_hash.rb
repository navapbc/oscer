# frozen_string_literal: true

# TODO: should probably just use store_model, but go barebones for the moment
module JsonHash
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def to_type
      JsonType.new.set_type(self)
    end
  end
end

class JsonType < ActiveRecord::Type::Json
  def set_type(klass)
    @klass = klass
    self
  end

  def cast(value)
    return nil if value.nil?

    return value if value.is_a?(@klass)

    case value
    when Hash
      @klass.new_filtered(value)
    else
      nil
    end
  end

  def deserialize(value)
    self.cast(super(value))
  end
end
