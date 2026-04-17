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

  # Ex parte CE: see CommunityEngagementCheckService (combined hours/income determination + events).
  system_process(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, ->(kase) {
    CommunityEngagementCheckService.determine(kase)
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
  # DeterminedHoursMet: At least one CE track (hours or income) satisfied
  # DeterminedActionRequired: Both tracks failed and no ex parte hours on file (member reports from scratch)
  # DeterminedHoursInsufficient: Both tracks failed but some ex parte hours exist (payload may include +income_data+)
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
end
