# frozen_string_literal: true

require_relative "requirement_params"

class Certifications::Requirements < ValueObject
  include ::JsonHash

  CERTIFICATION_TYPE_OPTIONS = [ "new_application", "recertification" ].freeze

  attribute :certification_date, :date
  attribute :certification_type, :enum, options: CERTIFICATION_TYPE_OPTIONS, default: nil

  # TODO: could do something like
  # "lookback": {
  #   "start": requirement_params.certification_date.beginning_of_month << requirement_params.lookback_period,
  #   "end": requirement_params.certification_date.beginning_of_month << 1
  # },
  # but a list of the months feels potentially more usable, alt name "months_to_consider"?
  attribute :months_that_can_be_certified, :array, of: ActiveModel::Type::Date.new
  attribute :number_of_months_to_certify, :integer
  attribute :due_date, :date

  # input params
  attribute :params, Certifications::RequirementParams.to_type

  validates :certification_date, presence: true
  validates :months_that_can_be_certified, presence: true
  validates :number_of_months_to_certify, presence: true
  validates :due_date, presence: true

  def continuous_lookback_period?
    months_that_can_be_certified = self.months_that_can_be_certified
    range = self.certification_lookback_date_range

    num_months_that_can_be_certified = months_that_can_be_certified.length
    # +1 to the difference since this list is inclusive
    num_months_in_range = DateUtils.month_difference(range.start, range.end) + 1

    num_months_that_can_be_certified == num_months_in_range
  end

  def continuous_lookback_period
    return nil unless self.continuous_lookback_period?

    self.certification_lookback_date_range
  end

  private

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
