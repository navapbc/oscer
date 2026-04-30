# frozen_string_literal: true

# Aggregates verified income for a certification lookback, compares to the monthly threshold,
# and (via CertificationCase#record_income_compliance) persists automated determinations from +#calculate+.
#
# Silent +#calculate+ matches +HoursComplianceDeterminationService#calculate+: no Strata workflow events,
# and compliant outcomes close the case (see +CertificationCase#record_income_compliance+ and its
# +close_on_compliant+ keyword for a future record-only mode).
# Combined ex parte CE assessment and Strata workflow events live in +CommunityEngagementCheckService+.
# Single source for TARGET_INCOME_MONTHLY (CE compliance UI and statistics; parity with
# HoursComplianceDeterminationService::TARGET_HOURS) via Rails.application.config.ce_compliance.
class IncomeComplianceDeterminationService
  TARGET_INCOME_MONTHLY = Rails.application.config.ce_compliance[:income_threshold_monthly]

  class << self
    # Shared threshold check for combined CE (+CommunityEngagementCheckService+) and +#calculate+.
    # @param total_income [Numeric]
    # @return [Boolean]
    def compliant_for_total_income?(total_income)
      total_income >= TARGET_INCOME_MONTHLY
    end

    # Silent recalculation (e.g. after +IncomeService+ saves a row for an open case). Same contract as
    # +HoursComplianceDeterminationService#calculate+: no +Strata::EventManager.publish+, and compliant
    # outcomes close the case via +record_income_compliance+ (default +close_on_compliant: true+).
    # @param certification_id [String]
    # @return [void]
    def calculate(certification_id)
      certification = Certification.find(certification_id)
      kase = certification_case_for_member_income(certification, nil)
      raise ActiveRecord::RecordNotFound, "Couldn't find CertificationCase for Certification #{certification_id}" unless kase

      income_data = aggregate_income_for_certification(certification, certification_case: kase)
      outcome = determine_outcome(income_data[:total_income])

      kase.record_income_compliance(outcome, income_data)
    end

    # Same lookback and query shape as ActivityAggregator#fetch_ex_parte_activities /
    # Income.for_member(...).within_period(lookback) as used for ex parte hours parity.
    # @param certification [Certification]
    # @param certification_case [CertificationCase, nil] When nil, resolves the case that owns the activity report (if any) so member income is not read from the wrong row when multiple cases share a certification_id (e.g. test factories).
    # @return [Hash]
    def aggregate_income_for_certification(certification, certification_case: nil)
      lookback = certification.certification_requirements.continuous_lookback_period
      rows = Income.for_member(certification.member_id).within_period(lookback)

      ex_total = BigDecimal(rows.sum(:gross_income).to_s)
      resolved_case = certification_case_for_member_income(certification, certification_case)
      member_total = member_reported_income_total(certification, certification_case: resolved_case)

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

    # Member-reported +IncomeActivity+ rows on the case activity report, scoped to the certification lookback.
    # Used by staff case income table and +#member_reported_income_total+.
    #
    # +IncomeActivity#income+ is a Strata +:money+ attribute on the +activities+ row, not an ActiveRecord
    # association, so +includes(:income)+ does not apply and does not address N+1 for dollar amounts.
    #
    # @param certification [Certification]
    # @param certification_case [CertificationCase, nil] See {.aggregate_income_for_certification}
    # @return [ActiveRecord::Relation<Activity>]
    def member_income_activities_for_certification(certification, certification_case: nil)
      kase = certification_case_for_member_income(certification, certification_case)
      return Activity.none unless kase

      form = ActivityReportApplicationForm.find_by(certification_case_id: kase.id)
      return Activity.none unless form

      lookback = certification.certification_requirements.continuous_lookback_period
      return Activity.none unless lookback&.start.present? && lookback.end.present?

      # Use Date values (not Date.parse on #to_s) so bounds match Strata::DateRange / certification month rows.
      start_date = lookback.start.to_date
      end_date = lookback.end.to_date.end_of_month

      form.activities.where(type: IncomeActivity.name).where(month: start_date..end_date).order(:month, :created_at)
    end

    private

    # When multiple +CertificationCase+ rows share a +certification_id+, +find_by(certification_id:)+ is
    # nondeterministic and may return a case with no activity report, yielding empty member income.
    #
    # Resolution (OSCER-408): prefer the case that has an +ActivityReportApplicationForm+ (newest by
    # +created_at+ if several); otherwise fall back to the newest case. Callers that know the correct
    # case (e.g. +CertificationCasesController#show+ with +@case+) should pass +certification_case:+ so
    # aggregation matches the staff view. Product has not required a different tie-break; revisit if
    # multiple open cases with activity reports become a supported scenario.
    def certification_case_for_member_income(certification, certification_case)
      return certification_case if certification_case

      scoped = CertificationCase.where(certification_id: certification.id)
      with_form = scoped.where(id: ActivityReportApplicationForm.select(:certification_case_id)).order(created_at: :desc).first
      with_form || scoped.order(created_at: :desc).first
    end

    def determine_outcome(total_income)
      compliant_for_total_income?(total_income) ? :compliant : :not_compliant
    end

    # Sum of approved member income activities on the activity report within the lookback (OSCER-405).
    # @param certification [Certification]
    # @param certification_case [CertificationCase, nil]
    # @return [BigDecimal]
    def member_reported_income_total(certification, certification_case: nil)
      member_income_activities_for_certification(certification, certification_case: certification_case).inject(BigDecimal("0")) do |sum, activity|
        sum + BigDecimal((activity.income&.dollar_amount || 0).to_s)
      end
    end
  end
end
