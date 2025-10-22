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
