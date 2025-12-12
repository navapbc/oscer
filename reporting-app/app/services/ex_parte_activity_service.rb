# frozen_string_literal: true

# Service for creating and validating ExParteActivity entries.
# Used by both API and batch upload for consistent data intake.
#
# Note: Hours aggregation is handled by HoursComplianceDeterminationService
# which includes lookback period filtering required for compliance calculations.
class ExParteActivityService
  class << self
    # Create hours data entry for a member
    # @return [ExParteActivity] on success
    # @return [Hash] with :error, :status keys on failure
    def create_entry(member_id:, category:, hours:, period_start:, period_end:,
                     source_type:, source_id: nil)
      if duplicate_entry?(member_id:, category:, hours:, period_start:, period_end:)
        return { error: "Duplicate entry", status: :conflict }
      end

      entry = ExParteActivity.new(
        member_id: member_id,
        category: category,
        hours: hours,
        period_start: period_start,
        period_end: period_end,
        source_type: source_type,
        source_id: source_id
      )

      if entry.save
        entry
      else
        { error: entry.errors.full_messages.join(", "), status: :unprocessable_entity }
      end
    end

    # Check for exact duplicate entry
    # @return [Boolean]
    def duplicate_entry?(member_id:, category:, hours:, period_start:, period_end:)
      ExParteActivity.exists?(
        member_id: member_id,
        category: category,
        hours: hours,
        period_start: period_start,
        period_end: period_end
      )
    end
  end
end
