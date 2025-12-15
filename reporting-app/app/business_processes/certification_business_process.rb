# frozen_string_literal: true

class CertificationBusinessProcess < Strata::BusinessProcess
  EX_PARTE_EXEMPTION_CHECK_STEP = "ex_parte_exemption_check"
  EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP = "ex_parte_community_engagement_check"
  REPORT_ACTIVITIES_STEP = "report_activities"
  REVIEW_ACTIVITY_REPORT_STEP = "review_activity_report"
  REVIEW_EXEMPTION_CLAIM_STEP = "review_exemption_claim"
  END_STEP = "end"

  system_process(EX_PARTE_EXEMPTION_CHECK_STEP, ->(kase) {
    ExemptionDeterminationService.determine(kase)
  })
  system_process(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, ->(kase) {
    HoursComplianceDeterminationService.determine(kase)
  })

  applicant_task(REPORT_ACTIVITIES_STEP)
  staff_task(REVIEW_ACTIVITY_REPORT_STEP, ReviewActivityReportTask)
  staff_task(REVIEW_EXEMPTION_CLAIM_STEP, ReviewExemptionClaimTask)

  # define start step
  start(EX_PARTE_EXEMPTION_CHECK_STEP, on: "CertificationCreated") do |event|
    CertificationCase.new(certification_id: event[:payload][:certification_id])
  end

  # define transitions
  transition(EX_PARTE_EXEMPTION_CHECK_STEP, "DeterminedNotExempt", EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP)
  transition(EX_PARTE_EXEMPTION_CHECK_STEP, "DeterminedExempt", END_STEP)
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedRequirementsNotMet", REPORT_ACTIVITIES_STEP)
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedRequirementsMet", END_STEP)

  transition(REPORT_ACTIVITIES_STEP, "ActivityReportApplicationFormSubmitted", REVIEW_ACTIVITY_REPORT_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "DeterminedRequirementsMet", END_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "DeterminedRequirementsNotMet", END_STEP)

  transition(REPORT_ACTIVITIES_STEP, "ExemptionApplicationFormSubmitted", REVIEW_EXEMPTION_CLAIM_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedExempt", END_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedNotExempt", REPORT_ACTIVITIES_STEP)
end
