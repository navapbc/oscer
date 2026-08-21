# frozen_string_literal: true

# Service for creating and validating ExternalHourlyActivity entries.
# Used by both API and batch upload for consistent data intake.
#
# Note: Hours aggregation is handled by HoursComplianceDeterminationService
# which includes lookback period filtering required for compliance calculations.
class ExternalHourlyActivityService
  # Matches the scale of external_hourly_activities.hours
  HOURS_SCALE = 2

  class << self
    # Create one hours data entry per calendar month the period touches, apportioning
    # hours by the number of covered days in each month.
    # @return [Array<ExternalHourlyActivity>] on success
    # @raise [ActiveRecord::RecordInvalid] on duplicate entry or validation failure
    def create_entries(member_id:, category:, hours:, period_start:, period_end:,
                       source_type:, source_id: nil)
      months = month_periods(period_start, period_end)

      # Malformed input (blank hours or dates, reversed period) goes to the model as-is
      # so it raises RecordInvalid rather than failing in the arithmetic below.
      if hours.blank? || months.size <= 1
        return [ create_entry(member_id:, category:, hours:, period_start:, period_end:,
                              source_type:, source_id:) ]
      end

      total_days = period_end - period_start + 1
      covered_days = 0
      allocated = 0

      months.map do |current_period_start, current_period_end|
        # Apportion against the running total rather than per month, so rounding cannot
        # drift and the entries always sum back to +hours+.
        covered_days += current_period_end - current_period_start + 1
        cumulative_hours = (covered_days * hours / total_days).round(HOURS_SCALE)
        current_hours = cumulative_hours - allocated
        allocated = cumulative_hours

        create_entry(member_id:, category:, hours: current_hours,
                     period_start: current_period_start,
                     period_end: current_period_end,
                     source_type:, source_id:)
      end
    end

    # Create hours data entry for a member
    # @return [ExternalHourlyActivity] on success
    # @raise [ActiveRecord::RecordInvalid] on duplicate entry or validation failure
    def create_entry(member_id:, category:, hours:, period_start:, period_end:,
                     source_type:, source_id: nil)
      entry = ExternalHourlyActivity.new
      if duplicate_entry?(member_id:, category:, hours:, period_start:, period_end:)
        entry.errors.add(:base, "Duplicate entry")
        raise ActiveRecord::RecordInvalid.new(entry)
      end

      entry.update!(
        member_id: member_id,
        category: category,
        hours: hours,
        period_start: period_start,
        period_end: period_end,
        source_type: source_type,
        source_id: source_id
      )

      entry
    end

    # Check for exact duplicate entry
    # @return [Boolean]
    def duplicate_entry?(member_id:, category:, hours:, period_start:, period_end:)
      ExternalHourlyActivity.exists?(
        member_id: member_id,
        category: category,
        hours: hours,
        period_start: period_start,
        period_end: period_end
      )
    end

    private

    # One [start, end] pair per calendar month the period touches, each clamped to the
    # period so the first and last months cover only their reported days.
    # Empty when the period is blank or reversed.
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
  end
end
