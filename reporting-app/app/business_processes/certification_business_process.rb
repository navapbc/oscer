# frozen_string_literal: true

class CertificationBusinessProcess < Strata::BusinessProcess
  # Determination steps
  EX_PARTE_EXEMPTION_CHECK_STEP = "ex_parte_exemption_check"
  EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP = "ex_parte_community_engagement_check"
  RECALCULATE_HOURS_STEP = "recalculate_hours"

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

  system_process(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, ->(kase) {
    HoursComplianceDeterminationService.determine(kase)
  })

  system_process(RECALCULATE_HOURS_STEP, ->(kase) {
    HoursComplianceDeterminationService.determine_after_activity_report(kase)
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

  # --- Transitions: Ex parte hours check ---
  # DeterminedHoursMet: Hours requirement satisfied
  # DeterminedActionRequired: No ex parte hours found, member needs to report from scratch
  # DeterminedHoursInsufficient: Has some ex parte hours but needs more
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedHoursMet", END_STEP)
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedActionRequired", REPORT_ACTIVITIES_STEP)
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedHoursInsufficient", REPORT_ACTIVITIES_STEP)

  # --- Transitions: Activity report workflow ---
  transition(REPORT_ACTIVITIES_STEP, "ActivityReportApplicationFormSubmitted", REVIEW_ACTIVITY_REPORT_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "ActivityReportApproved", RECALCULATE_HOURS_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "ActivityReportDenied", REPORT_ACTIVITIES_STEP)

  # --- Transitions: Recalculate hours after activity report ---
  transition(RECALCULATE_HOURS_STEP, "DeterminedHoursMet", END_STEP)
  transition(RECALCULATE_HOURS_STEP, "DeterminedHoursInsufficient", REPORT_ACTIVITIES_STEP)

  # --- Transitions: Exemption claim workflow ---
  transition(REPORT_ACTIVITIES_STEP, "ExemptionApplicationFormSubmitted", REVIEW_EXEMPTION_CLAIM_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedExempt", END_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedNotExempt", REPORT_ACTIVITIES_STEP)
end
