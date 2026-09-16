# frozen_string_literal: true

require_relative "requirement_params"

class Certifications::Requirements < ValueObject
  include ActiveModel::AsJsonAttributeType

  CERTIFICATION_TYPE_OPTIONS = [ "new_application", "recertification", "change_in_circumstance" ].freeze

  attribute :certification_period_start, :date
  attribute :certification_period_end, :date
  attribute :certification_type, :enum, options: CERTIFICATION_TYPE_OPTIONS
  validates :certification_type, inclusion: { in: CERTIFICATION_TYPE_OPTIONS, message: "is not a valid option" }, allow_blank: true

  attribute :months_that_can_be_certified, :array, of: ActiveModel::Type::Date.new
  attribute :number_of_months_to_certify, :integer, default: 1
  attribute :due_date, :date
  attribute :region, :string
  attribute :seasonal_worker, :boolean, default: false
  attribute :self_employed, :boolean, default: false

  # input params
  attribute :params, Certifications::RequirementParams.to_type

  validates :months_that_can_be_certified, presence: true
  validate :months_that_can_be_certified_must_be_dates
  validate :due_date_must_be_a_date

  def continuous_lookback_period?
    months_that_can_be_certified = self.months_that_can_be_certified
    range = certification_lookback_date_range

    num_months_that_can_be_certified = months_that_can_be_certified.length
    # +1 to the difference since this list is inclusive
    num_months_in_range = DateUtils.month_difference(range.start, range.end) + 1

    num_months_that_can_be_certified == num_months_in_range
  end

  def continuous_lookback_period
    return nil unless continuous_lookback_period?

    certification_lookback_date_range
  end

  private

  # ActiveModel's date cast returns nil for an unparseable String and passes non-String
  # values through untouched, so [nil] and [99] both satisfy the presence check above.
  def months_that_can_be_certified_must_be_dates
    return if months_that_can_be_certified.blank? || months_that_can_be_certified.all?(Date)

    errors.add(:months_that_can_be_certified, :invalid)
  end

  # Mirrors RequirementParams: an array or integer would otherwise persist and crash
  # every reader of the field.
  def due_date_must_be_a_date
    return if due_date.nil? || due_date.is_a?(Date)

    errors.add(:due_date, :invalid)
  end

  def certification_lookback_date_range
    months_that_can_be_certified = self.months_that_can_be_certified
    return Strata::DateRange.new(start: nil, end: nil) if months_that_can_be_certified.blank?

    sorted_months = months_that_can_be_certified.sort

    Strata::DateRange.new(
      start: sorted_months.first,
      end: sorted_months.last
    )
  end
end
