# frozen_string_literal: true

class CertificationBusinessProcess < Strata::BusinessProcess
  # TODO: system process to do exemption check
  system_process("exemption_check", ->(kase) {
    Strata::EventManager.publish("DeterminedNotExempt", { case_id: kase.id })
  })
  # TODO: system process for Ex Parte Determination
  system_process("ex_parte_determination", ->(kase) {
    Strata::EventManager.publish("DeterminedRequirementsNotMet", { case_id: kase.id })
  })

  applicant_task("report_activities")
  staff_task("review_activity_report", ReviewActivityReportTask)
  staff_task("review_exemption_claim", ReviewExemptionClaimTask)

  # define start step
  start("exemption_check", on: "CertificationCreated") do |event|
    CertificationCase.new(certification_id: event[:payload][:certification_id])
  end

  # define transitions

  transition("exemption_check", "DeterminedNotExempt", "ex_parte_determination")
  transition("exemption_check", "DeterminedExempt", "end")
  transition("ex_parte_determination", "DeterminedRequirementsNotMet", "report_activities")
  transition("ex_parte_determination", "DeterminedRequirementsMet", "end")

  transition("report_activities", "ActivityReportApplicationFormSubmitted", "review_activity_report")
  transition("review_activity_report", "DeterminedRequirementsMet", "end")
  transition("review_activity_report", "DeterminedRequirementsNotMet", "end")

  transition("report_activities", "ExemptionApplicationFormSubmitted", "review_exemption_claim")
  transition("review_exemption_claim", "DeterminedExempt", "end")
  transition("review_exemption_claim", "DeterminedNotExempt", "report_activities")
end
