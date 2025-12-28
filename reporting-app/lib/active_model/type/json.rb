# frozen_string_literal: true

# TODO: potentially add to Strata if not going to recommend store_model or
# similar library
module ActiveModel
  module Type
    class Json < ActiveRecord::Type::Json
      attr_reader :klass

      def initialize(klass = HashWithIndifferentAccess)
        @klass = klass
      end

      def cast(value)
        return nil if value.nil?

        return value if value.is_a?(@klass)

        case value
        when Hash
          val = value.with_indifferent_access

          # use the less-error prone filtered create if available
          if @klass.respond_to?(:new_filtered)
            @klass.new_filtered(val)
          else
            # otherwise fallback to plain `new`
            @klass.new(val)
          end
        else
          nil
        end
      end

      def deserialize(value)
        cast(super(value))
      end

      def ==(other)
        self.class == other.class &&
          klass == other.klass
      end

      def hash
        [ self.class, klass ].hash
      end
    end
  end
end
