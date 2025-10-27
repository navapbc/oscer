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

  def self.underlying_types
    self.union_types.flat_map { |t| t.respond_to?(:underlying_types) ? t.underlying_types : t }
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

    union_obj = super({})
    union_obj.set_union_errors(*objs)

    union_obj
  end

  def set_union_errors(*args)
    @union_models = args
  end

  validate do |input|
    # TODO: possible to provide clearer message that you must fufill either set of properties?
    for union_model in @union_models
      for error in union_model.errors
        errors.add(error.attribute, error.type, **error.options) unless errors.added?(error.attribute, error.type)
      end
    end
  end
end
