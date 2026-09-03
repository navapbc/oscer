# frozen_string_literal: true

module ActivityAggregator
  # Matches the scale of external_activities.hours and external_activities.gross_income
  VALUE_SCALE = 2

  # Both fetches read the one +ExternalActivity+ table; +with_hours+ / +with_income+ do the
  # separating. The scope is not cosmetic: an unscoped relation would give +summarize_hours+ a
  # zero-valued category bucket for income-only rows and credit ids that contributed nothing.
  # A row carrying both values is returned by both, since it feeds both compliance tracks.
  def fetch_external_hourly_activities(certification)
    return ExternalActivity.none unless certification&.member_id

    lookback_period = certification.certification_requirements.continuous_lookback_period
    ExternalActivity.for_member(certification.member_id).within_period(lookback_period).with_hours
  end

  def fetch_external_income_activities(certification, lookback_period)
    return ExternalActivity.none unless certification&.member_id

    ExternalActivity.for_member(certification.member_id).within_period(lookback_period).with_income
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
      # The allocation below multiplies +hours+; an income-only row would raise. Callers should
      # pass a +with_hours+-scoped relation, but this method is public on the concern.
      next unless activity.hours?

      allocate_activity_to_months(activity, result)
    end
    result
  end

  # A relation is accepted as well as an array. Expects rows carrying +hours+ — pass a
  # +with_hours+-scoped relation, or income-only rows would land in +by_category+ as zeroes.
  def summarize_hours(activities)
    rows = activities.to_a

    {
      total: decimal_sum(rows, :hours).to_f,
      by_category: rows.group_by(&:category).transform_values { |group| decimal_sum(group, :hours).to_f },
      by_month: rows.group_by(&:month).transform_values { |group| decimal_sum(group, :hours) },
      ids: rows.map(&:id)
    }
  end

  # Expects rows carrying +gross_income+ — pass a +with_income+-scoped relation, or an income-only
  # month map would gain zero-valued entries. Do not pass +IncomeActivity+ / +activities+ here;
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
    apportioned_values_map(period_start, period_end, value, weight: :daily)
  end

  # Apportions evenly.
  def monthly_values_map(period_start, period_end, value)
    apportioned_values_map(period_start, period_end, value, weight: :monthly)
  end

  # Apportions several named values across one set of month periods using the same weights, so a
  # submission carrying both hours and gross_income divides both along the same month boundaries.
  # Returns [start, end, {name => share}] triples.
  #
  # Apportioning each value separately and zipping the results would not do: the single-value map
  # drops a month whose share rounds away, so a small value can lose a month a larger one keeps
  # and the two lists fall out of step. Here a month survives when *any* value has a non-zero
  # share, and a value whose own share rounded away is left nil for that month, rolled into a
  # later one by the running total.
  #
  # @param weight [Symbol] :daily (by days each month covers) or :monthly (evenly)
  # @return [Array<Array(Date, Date, Hash)>]
  def apportioned_multi_values_map(period_start, period_end, weight:, **values)
    whole_period = [ [ period_start, period_end, values ] ]
    months = month_periods(period_start, period_end)

    # Malformed input (blank values or dates, reversed period) goes to the model as-is so it
    # raises RecordInvalid rather than failing in the arithmetic below.
    return whole_period if values.values.all?(&:blank?) || months.size <= 1

    weights = month_weights(months, weight)
    shares = values.transform_values do |value|
      value.blank? ? Array.new(months.size) : apportioned_shares(value, weights)
    end

    entries = months.each_with_index.map do |(current_period_start, current_period_end), index|
      [ current_period_start, current_period_end, month_shares(shares, index) ]
    end

    entries.reject { |_, _, month_values| month_values.values.all?(&:nil?) }.presence || whole_period
  end

  private

  # +hours+ and +gross_income+ are decimal columns: sum them as BigDecimal so repeated additions
  # cannot drift, and let callers cast to Float for display.
  def decimal_sum(rows, attribute)
    rows.sum(BigDecimal("0")) { |row| BigDecimal((row.public_send(attribute) || 0).to_s) }
  end

  def apportioned_values_map(period_start, period_end, value, weight:)
    whole_period = [ [ period_start, period_end, value ] ]
    months = month_periods(period_start, period_end)

    # Malformed input (blank value or dates, reversed period) goes to the model as-is
    # so it raises RecordInvalid rather than failing in the arithmetic below.
    return whole_period if value.blank? || months.size <= 1

    shares = apportioned_shares(value, month_weights(months, weight))
    entries = months.zip(shares).map do |(current_period_start, current_period_end), share|
      [ current_period_start, current_period_end, share ]
    end

    # A share too small to survive rounding would fail the models' greater-than-zero
    # validations; drop it and let the running total roll it into the next month.
    entries.reject { |_, _, share| share.zero? }.presence || whole_period
  end

  def month_weights(months, weight)
    case weight
    when :daily then months.map { |month_start, month_end| month_end - month_start + 1 }
    when :monthly then Array.new(months.size, 1)
    else raise ArgumentError, "unknown apportionment weight #{weight.inspect}"
    end
  end

  # Apportions +value+ against a running total rather than per month, so rounding cannot drift
  # and the shares always sum back to +value+.
  def apportioned_shares(value, weights)
    total_weight = weights.sum # number of months or number of days
    covered_weight = 0
    allocated = 0

    weights.map do |weight|
      covered_weight += weight
      cumulative_value = (covered_weight * value / total_weight).round(VALUE_SCALE)
      share = cumulative_value - allocated
      allocated = cumulative_value

      share
    end
  end

  # One month's slice across every value, with a share that rounded away left nil so it fails no
  # greater-than-zero validation and does not keep the month alive on its own.
  def month_shares(shares, index)
    shares.transform_values do |value_shares|
      share = value_shares[index]
      share unless share.nil? || share.zero?
    end
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
