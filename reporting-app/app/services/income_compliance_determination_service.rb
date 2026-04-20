# frozen_string_literal: true

# Aggregates verified income for a certification lookback and compares to the monthly threshold.
# Ex parte CE workflow (aggregate + combined determination + Strata events) lives in
# +CommunityEngagementCheckService+; this service exposes +aggregate_income_for_certification+,
# +compliant_for_total_income?+, and +calculate+ for silent persistence (+CertificationCase#record_income_compliance+).
# Single source for TARGET_INCOME_MONTHLY (CE compliance UI and statistics; parity with
# HoursComplianceDeterminationService::TARGET_HOURS) via Rails.application.config.ce_compliance.
class IncomeComplianceDeterminationService
  TARGET_INCOME_MONTHLY = Rails.application.config.ce_compliance[:income_threshold_monthly]

  class << self
    # Silent recalculation (e.g. jobs) — records determination without publishing workflow events.
    # @param certification_id [String]
    # @return [void]
    def calculate(certification_id)
      certification = Certification.find(certification_id)
      kase = CertificationCase.find_by!(certification_id: certification_id)

      income_data = aggregate_income_for_certification(certification)
      outcome = determine_outcome(income_data[:total_income])

      kase.record_income_compliance(outcome, income_data)
    end

    # Same lookback and query shape as ActivityAggregator#fetch_ex_parte_activities /
    # Income.for_member(...).within_period(lookback) as used for ex parte hours parity.
    # @param certification [Certification]
    # @return [Hash]
    def aggregate_income_for_certification(certification)
      lookback = certification.certification_requirements.continuous_lookback_period
      rows = Income.for_member(certification.member_id).within_period(lookback)

      ex_total = BigDecimal(rows.sum(:gross_income).to_s)
      member_total = member_reported_income_total(certification)

      {
        total_income: ex_total + member_total,
        income_by_source: {
          income: ex_total,
          activity: member_total
        },
        income_ids: rows.pluck(:id),
        period_start: lookback&.start,
        period_end: lookback&.end
      }
    end

    # Whether aggregated income meets the monthly CE threshold. Single source for comparison
    # with +determine_outcome+ and +CommunityEngagementCheckService.determine+.
    # @param total_income [Numeric]
    # @return [Boolean]
    def compliant_for_total_income?(total_income)
      total_income >= TARGET_INCOME_MONTHLY
    end

    private

    def determine_outcome(total_income)
      compliant_for_total_income?(total_income) ? :compliant : :not_compliant
    end

    # Approved member-reported income (e.g. from activity report) — stub until modeled.
    # @param _certification [Certification]
    # @return [BigDecimal]
    def member_reported_income_total(_certification)
      # TODO(OSCER-405): Sum approved member income activities when that model/workflow exists.
      BigDecimal("0")
    end
  end
end
