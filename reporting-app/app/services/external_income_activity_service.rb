# frozen_string_literal: true

# Service for creating and validating ExternalIncomeActivity entries from API and batch intake.
# Mirrors ExternalHourlyActivityService for hours data.
#
# After a successful save, optional compliance recalculation (+recalculate_income_compliance+, default +true+)
# runs +IncomeComplianceDeterminationService.calculate+ for the member’s open case; compliant outcomes
# close the case (same as hours +HoursComplianceDeterminationService#calculate+). Certification intake
# passes +recalculate_income_compliance: false+ so rows created before the case exists do not run this path.
class ExternalIncomeActivityService
  include Strata::VirtualActor

  class << self
    include ActivityAggregator
    include OriginHash

    # Create one income data entry per calendar month the period touches.
    # A submission already on file is logged and skipped, leaving the caller's other work intact.
    # @param identity [Array] values beyond the name identifying whose income this is, folded into
    #   the fingerprint (household income passes the member's tax ID and date of birth).
    # @return [Array<ExternalIncomeActivity>] the entries created, empty for a duplicate
    # @raise [ActiveRecord::RecordInvalid] on validation failure
    def create_entries(member_id:, category:, gross_income:, period_start:, period_end:,
                       source_type:, source_id: nil, reported_at: Time.current, metadata: {},
                       name: nil, identity: [], employer: nil,
                       recalculate_income_compliance: true)
      origin_hash = origin_hash_for(member_id, category, gross_income, period_start, period_end, name, *identity)

      if duplicate_entry?(origin_hash)
        log_duplicate_submission(origin_hash, member_id:, category:, period_start:, period_end:)
        return []
      end

      month_values = if whole_months?(period_start, period_end)
        monthly_values_map(period_start, period_end, gross_income)
      else
        daily_values_map(period_start, period_end, gross_income)
      end

      entries = month_values.map do |current_period_start, current_period_end, current_gross_income|
        create_entry(member_id:, category:, gross_income: current_gross_income,
                     period_start: current_period_start, period_end: current_period_end,
                     source_type:, source_id:, reported_at:, metadata:, name:, employer:, origin_hash:,
                     recalculate_income_compliance: false)
      end

      maybe_recalculate_income_compliance(member_id) if recalculate_income_compliance
      entries
    end

    # Duplicate detection belongs to +create_entries+.
    # @param recalculate_income_compliance [Boolean] when +true+ (default), after save run silent income
    #   compliance for the open case (may +close!+ when compliant); +Certifications::CreationService+ passes +false+.
    # @return [ExternalIncomeActivity] on success
    # @raise [ActiveRecord::RecordInvalid] on validation failure
    def create_entry(member_id:, category:, gross_income:, period_start:, period_end:,
                     source_type:, source_id: nil, reported_at: Time.current, metadata: {},
                     name: nil, employer: nil, origin_hash: nil, recalculate_income_compliance: true)
      entry = ExternalIncomeActivity.new()

      Strata::AuditLog.record do |log|
        entry.update!(
          member_id: member_id,
          category: category,
          gross_income: gross_income,
          period_start: period_start,
          period_end: period_end,
          source_type: source_type,
          source_id: source_id,
          reported_at: reported_at,
          name: name,
          origin_hash: origin_hash,
          metadata: (metadata || {}).merge(employer.present? ? { "employer" => employer } : {})
        )

        log.add_line(
          actor: self,
          action: "external_income_activity.create",
          subject: entry,
          data: entry.attributes
        )
      end

      maybe_recalculate_income_compliance(entry.member_id) if recalculate_income_compliance
      entry
    end

    private

    def whole_months?(period_start, period_end)
      period_start&.beginning_of_month == period_start && period_end&.end_of_month == period_end
    end

    # Resolves the member’s open +CertificationCase+ and runs +IncomeComplianceDeterminationService.calculate+,
    # which records an income determination and closes the case when compliant (unless product later passes
    # +close_on_compliant: false+ at the +record_income_compliance+ call site).
    def maybe_recalculate_income_compliance(member_id)
      certification_id = CertificationCase.open_certification_id_for_member(member_id)
      return if certification_id.blank?

      IncomeComplianceDeterminationService.calculate(certification_id)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn(
        "ExternalIncomeActivityService: skipped income compliance recalculation " \
        "(case or certification missing) for member_id=#{member_id} " \
        "certification_id=#{certification_id}"
      )
    end

    def duplicate_entry?(origin_hash)
      return false if origin_hash.blank?

      ExternalIncomeActivity.exists?(origin_hash: origin_hash)
    end
  end
end
