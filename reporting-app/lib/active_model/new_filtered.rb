# frozen_string_literal: true

module ActiveModel
  module NewFiltered
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def attr_syms
        self.attribute_names.map(&:to_sym)
      end

      def new_filtered(sliceable)
        case sliceable
        when Hash
          obj = sliceable.with_indifferent_access
        else
          obj = sliceable
        end

        self.new(obj.slice(*self.attr_syms))
      end
    end
  end
end
