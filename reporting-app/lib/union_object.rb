# frozen_string_literal: true

# TODO: find better place and name for this
class UnionObject
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serializers::JSON
  include ActiveModel::NewFiltered

  def self.build(types)
    union_class_name = types.map { |type| type.name.to_s.split("::").join("") }.join("Or")

    klass = Object.const_set(union_class_name, Class.new(self) do
      def self.union_types
        self.class_variable_get(:@@union_types)
      end
    end
    )

    klass.class_variable_set(:@@union_types, types)

    klass
  end

  def self.union_types
    raise "this method should be overriden and return classes of the union"
  end

  def self.underlying_types
    self.union_types.flat_map { |t| t.respond_to?(:underlying_types) ? t.underlying_types : t }
  end

  def self.attribute_names
    self.union_types.flat_map { |t| t.attribute_names }
  end

  def self.new(attributes = {})
    objs = []

    for t in self.union_types
      # TODO: put requirement on implementing this, or begin/rescue errors here
      obj = t.new_filtered(attributes)
      if obj.valid?
        return obj
      else
        objs.push(obj)
      end
    end

    union_obj = super({})
    union_obj.set_union_errors(*objs)

    union_obj
  end

  def set_union_errors(*args)
    @union_models = args
  end

  validate do |input|
    # TODO: possible to provide clearer message that you must fufill either set of properties?
    #
    # TODO: this is simpler but duplicates
    # @union_models.each { |union_model| errors.merge!(union_model.errors) }

    for union_model in @union_models
      for error in union_model.errors
        # TODO: errors.added? will fail if any error doesn't have a symbol type, but just a message...begin/rescue?
        errors.add(error.attribute, error.type, **error.options) unless errors.added?(error.attribute, error.type)
      end
    end
  end
end
