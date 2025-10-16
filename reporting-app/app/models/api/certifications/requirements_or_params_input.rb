# frozen_string_literal: true

class Api::Certifications::RequirementParamsInput < Certifications::RequirementTypeParams
  attribute :certification_date, :date
  attribute :certification_type, :string, default: nil

  attribute :due_date, :date

  validates :certification_date, presence: true

  # either :certification_type or all type params are required
  validates :certification_type, presence: true, if: Proc.new { |params| params.has_missing_type_params? }
  validates :lookback_period, presence: true, if: Proc.new { |params| params.certification_type.blank? }
  validates :number_of_months_to_certify, presence: true, if: Proc.new { |params| params.certification_type.blank? }

  # either :due_date or :due_period_days is required, if :certification_type not specified
  validates :due_period_days, presence: true, if: Proc.new { |params| params.certification_type.blank? && params.due_date.blank? }
  validates :due_date, presence: true, if: Proc.new { |params| params.certification_type.blank? && params.due_period_days.blank? }

  def with_type_params(requirement_type_params)
    self.lookback_period = requirement_type_params.lookback_period
    self.number_of_months_to_certify = requirement_type_params.number_of_months_to_certify
    self.due_period_days = requirement_type_params.due_period_days
  end

  def has_missing_type_params?
    for type_param in Certifications::RequirementTypeParams.attribute_names
      if self.attributes[type_param].blank?
        return true
      end
    end

    false
  end
end


# Ultimately this is meant to be a type like:
#
#  Certifications::Requirements | Certification::RequirementParams
#
# But Ruby/Rails makes that union awkward to model directly.
class Api::Certifications::RequirementsOrParamsInput < UnionObject
  include ::JsonHash

  def self.union_types
    [ Certifications::Requirements, Api::Certifications::RequirementParamsInput ]
  end
end
