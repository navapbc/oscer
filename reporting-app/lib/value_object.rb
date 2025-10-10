# frozen_string_literal: true

# TODO: very similar to Strata::ValueObject, possibly can be replace by it, but
# need a place to iterate for now without another moving target
class ValueObject
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serializers::JSON
  include ActiveModel::NewFiltered

  validates_with ActiveModel::Validations::NestedAttributeValidator
end
