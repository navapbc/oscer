# frozen_string_literal: true

# Service to build monthly statistics for activity report views.
# Aggregates hours from both self-reported activities and ex parte (state-provided) data.
#
# This service handles cross-aggregate queries that the model should not perform.
class ActivityReportStatisticsService
  MINIMUM_MONTHLY_HOURS = ActivityReportApplicationForm::MINIMUM_MONTHLY_HOURS
  MINIMUM_MONTHLY_INCOME = ActivityReportApplicationForm::MINIMUM_MONTHLY_INCOME

  class << self
    include ActivityAggregator

    # Build monthly statistics combining self-reported and ex parte activities
    # @param activity_report [ActivityReportApplicationForm]
    # @param certification [Certification]
    # @return [Hash] monthly statistics keyed by Date (first of month)
    def build_monthly_statistics(activity_report, certification)
      # Eager load activities to avoid strict_loading violation
      activities = Activity.where(activity_report_application_form_id: activity_report.id)
      activities_by_month = activities.group_by(&:month)
      ex_parte_by_month = allocate_ex_parte_activities_by_month(fetch_ex_parte_activities(certification))

      # Get all months from both sources
      all_months = (activities_by_month.keys + ex_parte_by_month.keys).uniq

      all_months.each_with_object({}) do |month, result|
        activities = activities_by_month[month] || []
        ex_parte_data = ex_parte_by_month[month] || []

        result[month] = build_month_stats(activities, ex_parte_data)
      end
    end

    private

    def build_month_stats(activities, ex_parte_data)
      hourly_activities = activities.select { |act| act.is_a?(WorkActivity) }
      income_activities = activities.select { |act| act.is_a?(IncomeActivity) }

      # Calculate self-reported hours and ex_parte hours
      member_hours = hourly_activities.sum { |act| act.hours || 0 }.round(1)
      ex_parte_hours = ex_parte_data.sum { |data| data[:allocated_hours] }.round(1)
      summed_hours = member_hours + ex_parte_hours

      summed_income = income_activities.sum { |act| act.income.dollar_amount || 0 }.round(0)

      {
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
