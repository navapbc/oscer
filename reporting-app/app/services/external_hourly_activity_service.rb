# frozen_string_literal: true

# Service for creating and validating ExternalHourlyActivity entries.
# Used by both API and batch upload for consistent data intake.
#
# Note: Hours aggregation is handled by HoursComplianceDeterminationService
# which includes lookback period filtering required for compliance calculations.
class ExternalHourlyActivityService
  class << self
    include ActivityAggregator
    include OriginHash

    # Create one hours data entry per calendar month the period touches.
    # @return [Array<ExternalHourlyActivity>] on success
    # @raise [ActiveRecord::RecordInvalid] on duplicate entry or validation failure
    def create_entries(member_id:, category:, hours:, period_start:, period_end:,
                       source_type:, source_id: nil, name: nil)
      origin_hash = origin_hash_for(member_id, category, hours, period_start, period_end, name)

      if duplicate_entry?(origin_hash)
        entry = ExternalHourlyActivity.new
        entry.errors.add(:base, "Duplicate entry")
        raise ActiveRecord::RecordInvalid.new(entry)
      end

      daily_values_map(period_start, period_end, hours).map do |current_period_start, current_period_end, current_hours|
        create_entry(member_id:, category:, hours: current_hours,
                     period_start: current_period_start,
                     period_end: current_period_end,
                     source_type:, source_id:, origin_hash:)
      end
    end

    # Create hours data entry for a member. Duplicate detection belongs to +create_entries+.
    # @return [ExternalHourlyActivity] on success
    # @raise [ActiveRecord::RecordInvalid] on validation failure
    def create_entry(member_id:, category:, hours:, period_start:, period_end:,
                     source_type:, source_id: nil, origin_hash: nil)
      entry = ExternalHourlyActivity.new

      entry.update!(
        member_id: member_id,
        category: category,
        hours: hours,
        period_start: period_start,
        period_end: period_end,
        source_type: source_type,
        source_id: source_id,
        origin_hash: origin_hash
      )

      entry
    end

    # Entries carrying no fingerprint (rows written before this column existed) are
    # not duplicates of anything.
    # @return [Boolean]
    def duplicate_entry?(origin_hash)
      return false if origin_hash.blank?

      ExternalHourlyActivity.exists?(origin_hash: origin_hash)
    end
  end
end
