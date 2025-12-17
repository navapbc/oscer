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

  def certification
    @certification ||= CertificationService.new.find(certification_case_id, hydrate: true)&.certification
  end

  def ex_parte_activities
    @ex_parte_activities ||= if certification&.member_id
      lookback_period = certification.certification_requirements.continuous_lookback_period
      ExParteActivity.for_member(certification.member_id).within_period(lookback_period)
    else
      ExParteActivity.none
    end
  end

  def ex_parte_activities_by_month
    @ex_parte_activities_by_month ||= begin
      result = Hash.new { |h, k| h[k] = [] }

      ex_parte_activities.each do |activity|
        allocate_activity_to_months(activity, result)
      end

      result
    end
  end

  # TODO: Consolidate with similar logic in HoursComplianceDeterminationService
  def monthly_statistics
    @monthly_statistics ||= begin
      # Get all months from both activities and ex_parte activities
      all_months = (activities_by_month.keys + ex_parte_activities_by_month.keys).uniq

      all_months.each_with_object({}) do |month, result|
        activities = activities_by_month[month] || []
        ex_parte_data = ex_parte_activities_by_month[month] || []

        hourly_activities = activities.select { |act| act.is_a?(WorkActivity) }
        income_activities = activities.select { |act| act.is_a?(IncomeActivity) }

        # Calculate self-reported hours and ex_parte hours
        member_hours = hourly_activities.sum { |act| act.hours || 0 }.round(1)
        ex_parte_hours = ex_parte_data.sum { |data| data[:allocated_hours] }.round(1)
        summed_hours = member_hours + ex_parte_hours

        summed_income = income_activities.sum { |act| act.income.dollar_amount || 0 }.round(0)

        result[month] = {
          hourly_activities: hourly_activities,
          income_activities: income_activities,
          ex_parte_activities: ex_parte_data,
          summed_hours: summed_hours,
          summed_income: summed_income,
          remaining_hours: [ MINIMUM_MONTHLY_HOURS - summed_hours, 0 ].max,
          remaining_income: [ MINIMUM_MONTHLY_INCOME - summed_income, 0 ].max
        }
      end
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

  def reporting_period_dates
    reporting_periods
      .sort_by { |ym| [ -ym.year, -ym.month ] }
      .map { |ym| Date.new(ym.year, ym.month, 1) }
  end

  private

  def allocate_activity_to_months(activity, result)
    start_date = activity.period_start
    end_date = activity.period_end
    total_days = (end_date - start_date).to_i + 1

    current_date = start_date
    while current_date <= end_date
      month_start = [ current_date, current_date.beginning_of_month ].max
      month_end = [ end_date, current_date.end_of_month ].min
      days_in_month = (month_end - month_start).to_i + 1

      # Calculate proportional hours for this month
      hours_for_month = (activity.hours * days_in_month / total_days.to_f).round(2)

      # Use Date (first day of month) as key to match activities_by_month
      month_key = Date.new(current_date.year, current_date.month, 1)

      result[month_key] << {
        activity: activity,
        allocated_hours: hours_for_month,
        days_in_month: days_in_month
      }

      # Move to next month
      current_date = current_date.next_month.beginning_of_month
    end
  end

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
