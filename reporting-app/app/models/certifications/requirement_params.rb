# frozen_string_literal: true

class Certifications::RequirementParams < Certifications::RequirementTypeParams
  attribute :certification_date, :date
  attribute :certification_type, :string, default: nil

  attribute :due_date, :date

  attribute :region, :string

  validates :certification_date, presence: true
  validates :lookback_period, presence: true
  validates :number_of_months_to_certify, presence: true
  # one or the other
  validates :due_period_days, presence: true, if: Proc.new { |params| params.due_date.blank? }
  validates :due_date, presence: true, if: Proc.new { |params| params.due_period_days.blank? }
  after_validation :set_due_date_from_period

  before_validation :set_type_params

  def set_type_params
    if certification_type.blank? || !Certifications::Requirements::CERTIFICATION_TYPE_OPTIONS.include?(certification_type)
      return
    end

    set_params_for_type(certification_type)
    # unset any existing explicit due_date
    self.due_date = nil
  end

  def to_requirements
    Certifications::Requirements.new({
      "certification_date": certification_date,
      "certification_type": certification_type,
      "months_that_can_be_certified": months_that_can_be_certified,
      "number_of_months_to_certify": number_of_months_to_certify,
      "due_date": due_date,
      "region": region,
      "params": as_json
    })
  end

  def months_that_can_be_certified
    lookback_period.times.map { |i| certification_date.beginning_of_month << i }
  end

  private

  def set_due_date_from_period
    if due_period_days
      self.due_date ||= certification_date + due_period_days.days
    end
  end
end
