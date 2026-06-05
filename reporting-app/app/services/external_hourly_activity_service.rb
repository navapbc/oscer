# frozen_string_literal: true

# Service for creating and validating ExternalHourlyActivity entries.
# Used by both API and batch upload for consistent data intake.
#
# Note: Hours aggregation is handled by HoursComplianceDeterminationService
# which includes lookback period filtering required for compliance calculations.
class ExternalHourlyActivityService
  class << self
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
  end
end
