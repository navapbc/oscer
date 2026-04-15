# frozen_string_literal: true

class CertificationBusinessProcess < Strata::BusinessProcess
  # Determination steps
  EX_PARTE_EXEMPTION_CHECK_STEP = "ex_parte_exemption_check"
  EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP = "ex_parte_community_engagement_check"

  # User task steps
  REPORT_ACTIVITIES_STEP = "report_activities"
  REVIEW_ACTIVITY_REPORT_STEP = "review_activity_report"
  REVIEW_EXEMPTION_CLAIM_STEP = "review_exemption_claim"

  END_STEP = "end"

  # --- System processes: Determination ---
  # Notifications are sent via NotificationsEventListener which subscribes to domain events
  system_process(EX_PARTE_EXEMPTION_CHECK_STEP, ->(kase) {
    ExemptionDeterminationService.determine(kase)
  })

  # Ex parte CE check: hours path first, then income aggregate, else existing hours insufficient /
  # action-required behavior (same Strata event names as today).
  #
  # Branching order (confirm with PM: hours-first vs parallel):
  # 1. If total hours (ex parte + member activity) meet the CE hours target →
  #    {HoursComplianceDeterminationService.determine} only (records hours determination; publishes
  #    DeterminedHoursMet / DeterminedHoursInsufficient / DeterminedActionRequired as today).
  # 2. Else if aggregated income for the certification lookback meets the monthly income threshold →
  #    {IncomeComplianceDeterminationService.determine} (records income determination; publishes
  #    the same event names for workflow parity).
  # 3. Else → {HoursComplianceDeterminationService.determine} (neither path satisfied; hours-based
  #    notifications and determination_data).
  system_process(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, ->(kase) {
    CertificationBusinessProcess.run_ex_parte_community_engagement_check(kase)
  })

  # User tasks
  applicant_task(REPORT_ACTIVITIES_STEP)
  staff_task(REVIEW_ACTIVITY_REPORT_STEP, ReviewActivityReportTask)
  staff_task(REVIEW_EXEMPTION_CLAIM_STEP, ReviewExemptionClaimTask)

  # --- Start ---
  start(EX_PARTE_EXEMPTION_CHECK_STEP, on: "CertificationCreated") do |event|
    CertificationCase.new(certification_id: event[:payload][:certification_id])
  end

  # --- Transitions: Ex parte exemption check ---
  transition(EX_PARTE_EXEMPTION_CHECK_STEP, "DeterminedNotExempt", EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP)
  transition(EX_PARTE_EXEMPTION_CHECK_STEP, "DeterminedExempt", END_STEP)

  # --- Transitions: Ex parte CE check (hours and/or income; same event names for workflow parity) ---
  # DeterminedHoursMet: CE satisfied via hours (hours branch) or via income aggregate (income branch;
  #    IncomeComplianceDeterminationService publishes this event for parity)
  # DeterminedActionRequired: No ex parte hours found, member needs to report from scratch
  # DeterminedHoursInsufficient: Has some ex parte hours but needs more (hours branch), or income branch
  #    not met with some ex parte income (see IncomeComplianceDeterminationService)
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedHoursMet", END_STEP)
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedActionRequired", REPORT_ACTIVITIES_STEP)
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedHoursInsufficient", REPORT_ACTIVITIES_STEP)

  # --- Transitions: Activity report workflow ---
  # Reviewer determines compliance: approved = compliant, denied = not compliant
  # Both outcomes close the case
  transition(REPORT_ACTIVITIES_STEP, "ActivityReportApplicationFormSubmitted", REVIEW_ACTIVITY_REPORT_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "ActivityReportApproved", END_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "ActivityReportDenied", END_STEP)

  # --- Transitions: Exemption claim workflow ---
  transition(REPORT_ACTIVITIES_STEP, "ExemptionApplicationFormSubmitted", REVIEW_EXEMPTION_CLAIM_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedExempt", END_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedNotExempt", REPORT_ACTIVITIES_STEP)

  # @param kase [CertificationCase]
  # @see system_process(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, ...) for branching order
  def self.run_ex_parte_community_engagement_check(kase)
    certification = Certification.find(kase.certification_id)
    hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)

    if hours_compliant?(hours_data)
      HoursComplianceDeterminationService.determine(kase)
    elsif income_compliant?(certification)
      IncomeComplianceDeterminationService.determine(kase)
    else
      HoursComplianceDeterminationService.determine(kase)
    end
  end

  def self.hours_compliant?(hours_data)
    hours_data[:total_hours].to_f >= HoursComplianceDeterminationService::TARGET_HOURS
  end

  def self.income_compliant?(certification)
    agg = IncomeComplianceDeterminationService.aggregate_income_for_certification(certification)
    IncomeComplianceDeterminationService.compliant_for_total_income?(agg[:total_income])
  end
end
