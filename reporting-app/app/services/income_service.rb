# frozen_string_literal: true

# Service for creating and validating Income entries from API and batch intake.
# Mirrors ExternalHourlyActivityService for hours data.
#
# After a successful save, optional compliance recalculation (+recalculate_income_compliance+, default +true+)
# runs +IncomeComplianceDeterminationService.calculate+ for the member’s open case; compliant outcomes
# close the case (same as hours +HoursComplianceDeterminationService#calculate+). Certification intake
# passes +recalculate_income_compliance: false+ so rows created before the case exists do not run this path.
class IncomeService
  class << self
    # Create income data entry for a member.
    # @param recalculate_income_compliance [Boolean] when +true+ (default), after save run silent income
    #   compliance for the open case (may +close!+ when compliant); +Certifications::CreationService+ passes +false+.
    # @return [Income] on success
    # @return [Hash] with :error key on failure
    def create_entry(member_id:, category:, gross_income:, period_start:, period_end:,
                     source_type:, source_id: nil, reported_at: Time.current, metadata: {}, employer: nil,
                     recalculate_income_compliance: true)
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
        maybe_recalculate_income_compliance(entry.member_id) if recalculate_income_compliance
        entry
      else
        { error: entry.errors.full_messages.join(", ") }
      end
    end

    private

    # Resolves the member’s open +CertificationCase+ and runs +IncomeComplianceDeterminationService.calculate+,
    # which records an income determination and closes the case when compliant (unless product later passes
    # +close_on_compliant: false+ at the +record_income_compliance+ call site).
    def maybe_recalculate_income_compliance(member_id)
      certification_id = CertificationCase.open_certification_id_for_member(member_id)
      return if certification_id.blank?

      IncomeComplianceDeterminationService.calculate(certification_id)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn(
        "IncomeService: skipped income compliance recalculation (case or certification missing) " \
        "for member_id=#{member_id} certification_id=#{certification_id}"
      )
    end

    # Same dimensions as ExternalHourlyActivityService duplicate check; source_type is not part of the key.
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
