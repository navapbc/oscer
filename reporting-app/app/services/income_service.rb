# frozen_string_literal: true

# Service for creating and validating Income entries from API and batch intake.
# Mirrors ExParteActivityService for hours data.
class IncomeService
  class << self
    # Create income data entry for a member
    # @return [Income] on success
    # @return [Hash] with :error key on failure
    def create_entry(member_id:, category:, gross_income:, period_start:, period_end:,
                     source_type:, source_id: nil, reported_at: Time.current, metadata: {}, employer: nil)
      if duplicate_entry?(
        member_id: member_id,
        category: category,
        gross_income: gross_income,
        period_start: period_start,
        period_end: period_end
      )
        return { error: "Duplicate entry" }
      end

      entry = Income.new(
        member_id: member_id,
        category: category,
        gross_income: gross_income,
        period_start: period_start,
        period_end: period_end,
        source_type: source_type,
        source_id: source_id,
        reported_at: reported_at,
        metadata: (metadata || {}).merge(employer.present? ? { "employer" => employer } : {})
      )

      if entry.save
        entry
      else
        { error: entry.errors.full_messages.join(", ") }
      end
    end

    private

    # Same dimensions as ExParteActivityService duplicate check; source_type is not part of the key.
    def duplicate_entry?(member_id:, category:, gross_income:, period_start:, period_end:)
      Income.exists?(
        member_id: member_id,
        category: category,
        gross_income: gross_income,
        period_start: period_start,
        period_end: period_end
      )
    end
  end
end
