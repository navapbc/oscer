# frozen_string_literal: true

# Service for creating and validating Income entries from API and batch intake.
# Mirrors ExParteActivityService for hours data.
class IncomeService
  class << self
    # Create income data entry for a member
    # @return [Income] on success
    # @return [Hash] with :error, :status keys on failure
    def create_entry(member_id:, category:, gross_income:, period_start:, period_end:,
                     source_type:, source_id: nil, reported_at: Time.current, metadata: {}, employer: nil)
      if duplicate_entry?(
        member_id: member_id,
        category: category,
        gross_income: gross_income,
        period_start: period_start,
        period_end: period_end
      )
        return { error: "Duplicate entry", status: :conflict }
      end

      merged_metadata = merge_metadata(metadata, employer)

      entry = Income.new(
        member_id: member_id,
        category: category,
        gross_income: gross_income,
        period_start: period_start,
        period_end: period_end,
        source_type: source_type,
        source_id: source_id,
        reported_at: reported_at,
        metadata: merged_metadata
      )

      if entry.save
        entry
      else
        { error: entry.errors.full_messages.join(", "), status: :unprocessable_entity }
      end
    end

    # Check for exact duplicate entry (same shape as ExParteActivityService; source_type is not part of the key)
    # @return [Boolean]
    def duplicate_entry?(member_id:, category:, gross_income:, period_start:, period_end:)
      Income.exists?(
        member_id: member_id,
        category: category,
        gross_income: gross_income,
        period_start: period_start,
        period_end: period_end
      )
    end

    private

    def merge_metadata(metadata, employer)
      base = {}.merge(metadata || {})
      return base unless employer.present?

      base.merge("employer" => employer)
    end
  end
end
