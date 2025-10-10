# frozen_string_literal: true

class Certifications::RequirementParams < Certifications::RequirementTypeParams
  attribute :certification_date, :date
  attribute :certification_type, :string, default: nil

  attribute :due_date, :date

  validates :certification_date, presence: true

  # ultimately before being used, we should have these
  validates :lookback_period, presence: true
  validates :number_of_months_to_certify, presence: true
  # one or the other
  validates :due_period_days, presence: true, if: Proc.new { |params| params.due_date.blank? }
  validates :due_date, presence: true, if: Proc.new { |params| params.due_period_days.blank? }

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
