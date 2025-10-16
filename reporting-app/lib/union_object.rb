# frozen_string_literal: true

# TODO: find better place and name for this
class UnionObject
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serializers::JSON
  include ActiveModel::NewFiltered

  def self.union_types
    raise "this method should be overriden and return classes of the union"
  end

  def self.attribute_names
    self.union_types.flat_map { |t| t.attribute_names }
  end

  def self.new(attributes = {})
    objs = []

    for t in self.union_types
      obj = t.new_filtered(attributes)
      if obj.valid?
        return obj
      else
        objs.push(obj)
      end
    end

    obj = super({})
    obj.set_union_errors(*objs)

    obj
  end

  def set_union_errors(*args)
    @union_models = args
  end

  validate do |input|
    # TODO: possible provide clearer message that you must fufill either set of properties?
    for union_model in @union_models
      for error in union_model.errors
        errors.add(error.attribute, error.type, **error.options)
      end
    end
  end
end
