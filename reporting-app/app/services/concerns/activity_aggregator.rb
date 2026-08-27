# frozen_string_literal: true

module ActivityAggregator
  # Matches the scale of external_hourly_activities.hours and external_income_activities.gross_income
  VALUE_SCALE = 2

  def fetch_external_hourly_activities(certification)
    return ExternalHourlyActivity.none unless certification&.member_id

    lookback_period = certification.certification_requirements.continuous_lookback_period
    ExternalHourlyActivity.for_member(certification.member_id).within_period(lookback_period)
  end

  def fetch_external_income_activities(certification, lookback_period)
    return ExternalIncomeActivity.none unless certification&.member_id

    ExternalIncomeActivity.for_member(certification.member_id).within_period(lookback_period)
  end

  def fetch_member_activities(form)
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

  # Both summaries load the rows once and total them in memory: +by_month+ needs every row anyway,
  # so SQL aggregates would only add round trips. A relation is accepted as well as an array.
  def summarize_hours(activities)
    rows = activities.to_a

    {
      total: decimal_sum(rows, :hours).to_f,
      by_category: rows.group_by(&:category).transform_values { |group| decimal_sum(group, :hours).to_f },
      by_month: rows.group_by(&:month).transform_values { |group| decimal_sum(group, :hours) },
      ids: rows.map(&:id)
    }
  end

  # Expects +ExternalIncomeActivity+ rows (+gross_income+). Do not pass +IncomeActivity+ / +activities+ here;
  # member self-report totals use +IncomeComplianceDeterminationService#member_income_totals_from_rows+.
  def summarize_income(activities)
    rows = activities.to_a

    {
      total: decimal_sum(rows, :gross_income),
      by_month: rows.group_by(&:month).transform_values { |group| decimal_sum(group, :gross_income) },
      ids: rows.map(&:id)
    }
  end

  def merge_external_with_member_data(external, member)
    (external.keys | member.keys).each_with_object({}) do |key, result|
      result[key] = (external[key] || 0.0) + (member[key] || 0.0)
    end
  end

  # Each pair is clamped to the period, so the first and last months cover only their
  # reported days. Empty when the period is blank or reversed.
  def month_periods(period_start, period_end)
    return [] if period_start.blank? || period_end.blank?

    month_start = period_start.beginning_of_month
    periods = []

    while month_start <= period_end
      periods << [ [ period_start, month_start ].max,
                   [ period_end, month_start.end_of_month ].min ]
      month_start += 1.month
    end

    periods
  end

  # Both maps below split +value+ across the calendar months the period touches and return
  # [start, end, value] triples; they differ only in how the value is apportioned.

  # Apportions by the number of days each month covers.
  def daily_values_map(period_start, period_end, value)
    apportioned_values_map(period_start, period_end, value) do |months|
      months.map { |month_start, month_end| month_end - month_start + 1 }
    end
  end

  # Apportions evenly.
  def monthly_values_map(period_start, period_end, value)
    apportioned_values_map(period_start, period_end, value) do |months|
      Array.new(months.size, 1)
    end
  end

  private

  # +hours+ and +gross_income+ are decimal columns: sum them as BigDecimal so repeated additions
  # cannot drift, and let callers cast to Float for display.
  def decimal_sum(rows, attribute)
    rows.sum(BigDecimal("0")) { |row| BigDecimal((row.public_send(attribute) || 0).to_s) }
  end

  # The block supplies the per-month weights to apportion by.
  def apportioned_values_map(period_start, period_end, value)
    whole_period = [ [ period_start, period_end, value ] ]
    months = month_periods(period_start, period_end)

    # Malformed input (blank value or dates, reversed period) goes to the model as-is
    # so it raises RecordInvalid rather than failing in the arithmetic below.
    return whole_period if value.blank? || months.size <= 1

    weights = yield(months)
    total_weight = weights.sum # number of months or number of days
    covered_weight = 0
    allocated = 0
    entries = months.zip(weights).map do |(current_period_start, current_period_end), weight|
      # Apportion against the running total rather than per month, so rounding cannot
      # drift and the entries always sum back to +value+.
      covered_weight += weight
      cumulative_value = (covered_weight * value / total_weight).round(VALUE_SCALE)
      current_value = cumulative_value - allocated
      allocated = cumulative_value

      [ current_period_start, current_period_end, current_value ]
    end

    # A share too small to survive rounding would fail the models' greater-than-zero
    # validations; drop it and let the running total roll it into the next month.
    entries.reject { |_, _, current_value| current_value.zero? }.presence || whole_period
  end


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
