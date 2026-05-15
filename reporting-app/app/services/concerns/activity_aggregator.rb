# frozen_string_literal: true

module ActivityAggregator
  def fetch_external_hourly_activities(certification)
    return ExternalHourlyActivity.none unless certification&.member_id

    lookback_period = certification.certification_requirements.continuous_lookback_period
    ExternalHourlyActivity.for_member(certification.member_id).within_period(lookback_period)
  end

  def fetch_external_income_activities(certification, lookback_period)
    return ExternalIncomeActivity.none unless certification&.member_id

    ExternalIncomeActivity.for_member(certification.member_id).within_period(lookback_period)
  end

  def fetch_member_activities(certification)
    certification_case = certification_case_for_certification(certification)
    return Activity.none unless certification_case

    form = ActivityReportApplicationForm.find_by(certification_case_id: certification_case.id)
    return Activity.none unless form

    form.activities
  end

  # Selects the CertificationCase to use for member activity / income / hours aggregation.
  # When +certification_case+ is given, returns it unchanged. Otherwise, when multiple
  # +CertificationCase+ rows share a +certification_id+ (unexpected in production, common in
  # test factories), prefers the case that owns an +ActivityReportApplicationForm+ (newest by
  # +created_at+); otherwise falls back to the newest case. Single source of truth for the
  # tie-break shared by +HoursComplianceDeterminationService+ and +IncomeComplianceDeterminationService+.
  # @param certification [Certification]
  # @param certification_case [CertificationCase, nil]
  # @return [CertificationCase, nil]
  def certification_case_for_certification(certification, certification_case = nil)
    return certification_case if certification_case

    cc_scoped = CertificationCase.where(certification_id: certification.id)
    return cc_scoped.first if cc_scoped.length <= 1

    Rails.logger.debug do
      "ActivityAggregator: multiple CertificationCases for certification_id=#{certification.id}; " \
        "tie-breaker selected newest case (with ActivityReportApplicationForm if any)."
    end
    cc_with_form = cc_scoped.where(id: ActivityReportApplicationForm.select(:certification_case_id))
      .order(created_at: :desc).first
    cc_with_form || cc_scoped.order(created_at: :desc).first
  end

  def allocate_external_hourly_activities_by_month(activities)
    result = Hash.new { |h, k| h[k] = [] }
    activities.each do |activity|
      allocate_activity_to_months(activity, result)
    end
    result
  end

  def summarize_hours(activities)
    if activities.is_a?(ActiveRecord::Relation)
      {
        total: activities.sum(:hours).to_f,
        by_category: activities.group(:category).sum(:hours).transform_values(&:to_f),
        ids: activities.pluck(:id)
      }
    else
      rows = Array(activities)
      {
        total: rows.sum { |row| row.hours.to_f },
        by_category: rows.group_by(&:category).transform_values { |group| group.sum { |row| row.hours.to_f } },
        ids: rows.map(&:id)
      }
    end
  end

  # Expects +ExternalIncomeActivity+ rows (+gross_income+). Do not pass +IncomeActivity+ / +activities+ here;
  # member self-report totals use +IncomeComplianceDeterminationService#member_income_totals_from_rows+.
  def summarize_income(activities)
    if activities.is_a?(ActiveRecord::Relation)
      {
        total: BigDecimal(activities.sum(:gross_income).to_s),
        ids: activities.pluck(:id)
      }
    else
      rows = Array(activities)
      {
        total: rows.sum { |row| BigDecimal(row.gross_income.to_s) },
        ids: rows.map(&:id)
      }
    end
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
