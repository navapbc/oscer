# frozen_string_literal: true

class CertificationBusinessProcess < Strata::BusinessProcess
  system_process("ex_parte_exemption_check", ->(kase) {
    ExemptionDeterminationService.determine(kase)
  })
  system_process("ex_parte_community_engagement_check", ->(kase) {
    Strata::EventManager.publish("DeterminedRequirementsNotMet", { case_id: kase.id })
  })

  applicant_task("report_activities")
  staff_task("review_activity_report", ReviewActivityReportTask)
  staff_task("review_exemption_claim", ReviewExemptionClaimTask)

  # define start step
  start("ex_parte_exemption_check", on: "CertificationCreated") do |event|
    CertificationCase.new(certification_id: event[:payload][:certification_id])
  end

  # define transitions

  transition("ex_parte_exemption_check", "DeterminedNotExempt", "ex_parte_community_engagement_check")
  transition("ex_parte_exemption_check", "DeterminedExempt", "end")
  transition("ex_parte_community_engagement_check", "DeterminedRequirementsNotMet", "report_activities")
  transition("ex_parte_community_engagement_check", "DeterminedRequirementsMet", "end")

  transition("report_activities", "ActivityReportApplicationFormSubmitted", "review_activity_report")
  transition("review_activity_report", "DeterminedRequirementsMet", "end")
  transition("review_activity_report", "DeterminedRequirementsNotMet", "end")

  transition("report_activities", "ExemptionApplicationFormSubmitted", "review_exemption_claim")
  transition("review_exemption_claim", "DeterminedExempt", "end")
  transition("review_exemption_claim", "DeterminedNotExempt", "report_activities")
end
