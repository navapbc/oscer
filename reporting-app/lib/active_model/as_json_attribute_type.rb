# frozen_string_literal: true

# TODO: should probably just use store_model, but go barebones for the moment
module ActiveModel
  module AsJsonAttributeType
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def to_type
        ActiveModel::Type::Json.new(self)
      end
    end
  end
end
