# frozen_string_literal: true

class ActivityReportApplicationForm < Strata::ApplicationForm
  MINIMUM_MONTHLY_HOURS = 80
  MINIMUM_MONTHLY_INCOME = 580

  has_many :activities, strict_loading: true, autosave: true, dependent: :destroy

  default_scope { includes(:determinations) }

  strata_attribute :reporting_periods, :year_month, array: true
  strata_attribute :number_of_months_to_certify, :integer
  strata_attribute :months_that_can_be_certified, :year_month, array: true

  validates :certification_case_id, presence: true, uniqueness: true
  validates :reporting_periods,
    length: {
      is: :number_of_months_to_certify,
      wrong_length: "You must select exactly %{count} month(s) to certify"
    },
    on: :reporting_period_selection,
    if: :number_of_months_to_certify
  validate :validate_reporting_periods_in_range, on: :reporting_period_selection, if: :months_that_can_be_certified

  def activities_by_id
    @activities_by_id ||= activities.index_by(&:id)
  end

  def activities_by_month
    @activities_by_month ||= activities.group_by(&:month)
  end

  def monthly_statistics
    @monthly_statistics ||= activities_by_month.transform_values do |activities|
      hourly_activities = activities.select { |act| act.is_a?(WorkActivity) }
      income_activities = activities.select { |act| act.is_a?(IncomeActivity) }
      summed_hours = hourly_activities.sum { |act| act.hours || 0 }.round(1)
      summed_income = income_activities.sum { |act| act.income.dollar_amount || 0 }.round(0)

      {
        hourly_activities: hourly_activities,
        income_activities: income_activities,
        summed_hours: summed_hours,
        summed_income: summed_income,
        remaining_hours: [ MINIMUM_MONTHLY_HOURS - summed_hours, 0 ].max,
        remaining_income: [ MINIMUM_MONTHLY_INCOME - summed_income, 0 ].max
      }
    end
  end

  default_scope { includes(:activities) }

  accepts_nested_attributes_for :activities, allow_destroy: true

  def self.find_by_certification_case_id(certification_case_id)
    find_by(certification_case_id:)
  end

  # Include the case id
  def event_payload
    super.merge(case_id: certification_case_id)
  end

  def self.information_request_class
    ActivityReportInformationRequest
  end

  def months_that_can_be_certified=(months)
    super(months.map { |v| { "year" => v.year, "month" => v.month } })
  end

  private

  def validate_reporting_periods_in_range
    invalid = reporting_periods - months_that_can_be_certified

    return true if invalid.empty?

    errors.add(
      :reporting_periods,
      "Months #{invalid.map { |month| Strata::YearMonth.new(month).strftime("%B %Y") }.join(', ')} are not valid for certification."
    )
    false
  end
end
