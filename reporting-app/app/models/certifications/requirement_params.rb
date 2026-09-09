# frozen_string_literal: true

class Certifications::RequirementParams < Certifications::RequirementTypeParams
  attribute :certification_date, :date
  attribute :certification_period_start, :date
  attribute :certification_period_end, :date
  attribute :certification_type, :string, default: nil

  attribute :due_date, :date

  attribute :region, :string

  validates :certification_date, presence: true
  validates :lookback_period, presence: true
  validates :number_of_months_to_certify, presence: true
  validates :due_date, presence: true
  validate :due_date_must_be_a_date

  before_validation :set_type_params
  before_validation :set_due_date_from_period

  def set_type_params
    if certification_type.blank? || !Certifications::Requirements::CERTIFICATION_TYPE_OPTIONS.include?(certification_type)
      return
    end

    set_params_for_type(certification_type)
  end

  # Keep the anchor an argument. RequirementParams is a union member whose valid? is type dispatch
  # (UnionObject#new), and the application date is not in the nested requirements hash, so
  # validating it here would match neither member. CreateRequest validates it.
  def to_requirements(application_date:)
    Certifications::Requirements.new({
      "certification_date": certification_date,
      "certification_period_start": certification_period_start,
      "certification_period_end": certification_period_end,
      "certification_type": certification_type,
      "months_that_can_be_certified": months_that_can_be_certified(application_date),
      "number_of_months_to_certify": number_of_months_to_certify,
      "due_date": due_date,
      "region": region,
      "params": as_json
    })
  end

  # Excludes the application month, which is still in progress.
  # TODO: recertifications should count forward from certification_period_start rather than back
  # from here. Deferred until the certification period contract is defined.
  def months_that_can_be_certified(application_date)
    lookback_period.times.map { |i| application_date.beginning_of_month << (i + 1) }
  end

  private

  def set_due_date_from_period
    self.due_date ||= Date.current + (due_period_days || DEFAULT_DUE_PERIOD_DAYS).days
  end

  # ActiveModel's date cast passes non-String values through untouched, so an
  # array or integer would otherwise persist and crash every reader of the field.
  def due_date_must_be_a_date
    return if due_date.nil? || due_date.is_a?(Date)

    errors.add(:due_date, :invalid)
  end
end
