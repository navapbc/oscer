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

  # Notification steps - each sends one specific email
  SEND_ACTION_REQUIRED_EMAIL_STEP = "send_action_required_email"
  SEND_COMPLIANT_EMAIL_STEP = "send_compliant_email"
  SEND_INSUFFICIENT_HOURS_EMAIL_STEP = "send_insufficient_hours_email"
  SEND_EXEMPT_EMAIL_STEP = "send_exempt_email"

  END_STEP = "end"

  # --- System processes: Determination ---
  system_process(EX_PARTE_EXEMPTION_CHECK_STEP, ->(kase) {
    ExemptionDeterminationService.determine(kase)
  })

  system_process(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, ->(kase) {
    HoursComplianceDeterminationService.determine(kase)
  })

  system_process(RECALCULATE_HOURS_STEP, ->(kase) {
    HoursComplianceDeterminationService.determine_after_activity_report(kase)
  })

  # --- System processes: Notifications (one email per step, then publish event to continue) ---
  system_process(SEND_ACTION_REQUIRED_EMAIL_STEP, ->(kase) {
    certification = Certification.find(kase.certification_id)
    NotificationService.send_email_notification(
      MemberMailer,
      { certification: certification },
      :action_required_email,
      [ certification.member_email ]
    )
    Strata::EventManager.publish("NotificationSent", { case_id: kase.id })
  })

  system_process(SEND_COMPLIANT_EMAIL_STEP, ->(kase) {
    certification = Certification.find(kase.certification_id)
    NotificationService.send_email_notification(
      MemberMailer,
      { certification: certification },
      :compliant_email,
      [ certification.member_email ]
    )
    Strata::EventManager.publish("NotificationSent", { case_id: kase.id })
  })

  system_process(SEND_INSUFFICIENT_HOURS_EMAIL_STEP, ->(kase) {
    certification = Certification.find(kase.certification_id)
    hours_data = HoursComplianceDeterminationService.aggregate_hours_for_certification(certification)
    NotificationService.send_email_notification(
      MemberMailer,
      {
        certification: certification,
        hours_data: hours_data,
        target_hours: HoursComplianceDeterminationService::TARGET_HOURS
      },
      :insufficient_hours_email,
      [ certification.member_email ]
    )
    Strata::EventManager.publish("NotificationSent", { case_id: kase.id })
  })

  system_process(SEND_EXEMPT_EMAIL_STEP, ->(kase) {
    certification = Certification.find(kase.certification_id)
    NotificationService.send_email_notification(
      MemberMailer,
      { certification: certification },
      :exempt_email,
      [ certification.member_email ]
    )
    Strata::EventManager.publish("NotificationSent", { case_id: kase.id })
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
  transition(EX_PARTE_EXEMPTION_CHECK_STEP, "DeterminedExempt", SEND_EXEMPT_EMAIL_STEP)

  # --- Transitions: Ex parte hours check ---
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedHoursMet", SEND_COMPLIANT_EMAIL_STEP)
  transition(EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedActionRequired", SEND_ACTION_REQUIRED_EMAIL_STEP)

  # --- Transitions: Notification steps → next workflow step ---
  transition(SEND_COMPLIANT_EMAIL_STEP, "NotificationSent", END_STEP)
  transition(SEND_ACTION_REQUIRED_EMAIL_STEP, "NotificationSent", REPORT_ACTIVITIES_STEP)
  transition(SEND_INSUFFICIENT_HOURS_EMAIL_STEP, "NotificationSent", REPORT_ACTIVITIES_STEP)
  transition(SEND_EXEMPT_EMAIL_STEP, "NotificationSent", END_STEP)

  # --- Transitions: Activity report workflow ---
  transition(REPORT_ACTIVITIES_STEP, "ActivityReportApplicationFormSubmitted", REVIEW_ACTIVITY_REPORT_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "ActivityReportApproved", RECALCULATE_HOURS_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "ActivityReportDenied", SEND_INSUFFICIENT_HOURS_EMAIL_STEP)

  # --- Transitions: Recalculate hours after activity report ---
  transition(RECALCULATE_HOURS_STEP, "DeterminedHoursMet", SEND_COMPLIANT_EMAIL_STEP)
  transition(RECALCULATE_HOURS_STEP, "DeterminedHoursInsufficient", SEND_INSUFFICIENT_HOURS_EMAIL_STEP)

  # --- Transitions: Exemption claim workflow ---
  transition(REPORT_ACTIVITIES_STEP, "ExemptionApplicationFormSubmitted", REVIEW_EXEMPTION_CLAIM_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedExempt", SEND_EXEMPT_EMAIL_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedNotExempt", REPORT_ACTIVITIES_STEP)
end
