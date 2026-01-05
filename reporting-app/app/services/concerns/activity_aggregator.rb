# frozen_string_literal: true

module ActivityAggregator
  def fetch_ex_parte_activities(certification)
    return ExParteActivity.none unless certification&.member_id

    lookback_period = certification.certification_requirements.continuous_lookback_period
    ExParteActivity.for_member(certification.member_id).within_period(lookback_period)
  end

  def fetch_member_activities(certification)
    certification_case = CertificationCase.find_by(certification_id: certification.id)
    return Activity.none unless certification_case

    form = ActivityReportApplicationForm.find_by(certification_case_id: certification_case.id)
    return Activity.none unless form

    form.activities
  end

  def allocate_ex_parte_activities_by_month(activities)
    result = Hash.new { |h, k| h[k] = [] }
    activities.each do |activity|
      allocate_activity_to_months(activity, result)
    end
    result
  end

  def summarize_hours(activities)
    {
      total: activities.sum(:hours).to_f,
      by_category: activities.group(:category).sum(:hours).transform_values(&:to_f),
      ids: activities.pluck(:id)
    }
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
