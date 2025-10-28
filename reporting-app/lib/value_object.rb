# frozen_string_literal: true

# TODO: very similar to Strata::ValueObject, possibly can be replace by it, but
# need a place to iterate for now without another moving target
class ValueObject
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serializers::JSON
  include ActiveModel::NewFiltered
  include ActiveModel::Validations::Callbacks
  include ActiveRecord::AttributeMethods::BeforeTypeCast

  validates_with ActiveModel::Validations::NestedAttributeValidator
  validates_with ActiveModel::Validations::AttributesTypeValidator

  # TODO: move this to a module that can just be included
  after_validation :dedupe_type_and_blank_errors

  def ==(other)
    return false if self.class != other.class
    self.as_json == other.as_json
  end

  private

  def dedupe_type_and_blank_errors
    return unless !self.errors.empty?

    deduped_errors = ActiveModel::Errors.new(self)

    for error in self.errors
      if error.type == :blank && self.errors.of_kind?(error.attribute, :invalid_value)
        next
      end

      deduped_errors.errors.append(error)
    end

    @errors = deduped_errors
  end
end
