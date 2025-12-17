# frozen_string_literal: true

# Service to build monthly statistics for activity report views.
# Aggregates hours from both self-reported activities and ex parte (state-provided) data.
#
# This service handles cross-aggregate queries that the model should not perform.
class ActivityReportStatisticsService
  MINIMUM_MONTHLY_HOURS = ActivityReportApplicationForm::MINIMUM_MONTHLY_HOURS
  MINIMUM_MONTHLY_INCOME = ActivityReportApplicationForm::MINIMUM_MONTHLY_INCOME

  class << self
    # Build monthly statistics combining self-reported and ex parte activities
    # @param activity_report [ActivityReportApplicationForm]
    # @param certification [Certification]
    # @return [Hash] monthly statistics keyed by Date (first of month)
    def build_monthly_statistics(activity_report, certification)
      activities_by_month = activity_report.activities.group_by(&:month)
      ex_parte_by_month = build_ex_parte_by_month(certification)

      # Get all months from both sources
      all_months = (activities_by_month.keys + ex_parte_by_month.keys).uniq

      all_months.each_with_object({}) do |month, result|
        activities = activities_by_month[month] || []
        ex_parte_data = ex_parte_by_month[month] || []

        result[month] = build_month_stats(activities, ex_parte_data)
      end
    end

    # Fetch ex parte activities for a certification
    # @param certification [Certification]
    # @return [ActiveRecord::Relation<ExParteActivity>]
    def fetch_ex_parte_activities(certification)
      return ExParteActivity.none unless certification&.member_id

      lookback_period = certification.certification_requirements.continuous_lookback_period
      ExParteActivity.for_member(certification.member_id).within_period(lookback_period)
    end

    private

    def build_ex_parte_by_month(certification)
      result = Hash.new { |h, k| h[k] = [] }

      fetch_ex_parte_activities(certification).each do |activity|
        allocate_activity_to_months(activity, result)
      end

      result
    end

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

    # Allocate an ex parte activity's hours across the months it spans
    # @param activity [ExParteActivity]
    # @param result [Hash] accumulator for monthly allocations
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

        # Use Date (first day of month) as key
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
  end
end
