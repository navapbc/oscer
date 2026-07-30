# frozen_string_literal: true

class CertificationBusinessProcess < Strata::BusinessProcess
  # Determination steps
  EXTERNAL_EXCLUSION_CHECK_STEP = "external_exclusion_check"
  EXTERNAL_EXCEPTION_CHECK_STEP = "external_exception_check"
  EXTERNAL_COMMUNITY_ENGAGEMENT_CHECK_STEP = "external_community_engagement_check"
  # Trailing step: where OSCER calls OUT, after the preceding steps assess data in hand (OSCER-805).
  VERIFICATION_DATA_SOURCE_CHECK_STEP = "verification_data_source_check"

  # User task steps
  REPORT_ACTIVITIES_STEP = "report_activities"
  REVIEW_ACTIVITY_REPORT_STEP = "review_activity_report"
  REVIEW_EXEMPTION_CLAIM_STEP = "review_exemption_claim"
  REVIEW_DENIAL_RESPONSE_STEP = "review_denial_response"

  END_STEP = "end"

  # --- System processes: Determination ---
  # Notifications are sent via NotificationsEventListener which subscribes to domain events

  # External exclusion: see ExclusionDeterminationService.
  system_process(EXTERNAL_EXCLUSION_CHECK_STEP, ->(kase) {
    ExclusionDeterminationService.determine(kase)
  })

  # External exception: see ExceptionDeterminationService.
  system_process(EXTERNAL_EXCEPTION_CHECK_STEP, ->(kase) {
    ExceptionDeterminationService.determine(kase)
  })

  # External CE: see CommunityEngagementCheckService (combined hours/income determination + events).
  system_process(EXTERNAL_COMMUNITY_ENGAGEMENT_CHECK_STEP, ->(kase) {
    CommunityEngagementCheckService.determine(kase)
  })

  # Verification data sources: see DataSourceCheckService. Owns the negative determination.
  system_process(VERIFICATION_DATA_SOURCE_CHECK_STEP, ->(kase) {
    DataSourceCheckService.determine(kase)
  })

  # User tasks
  applicant_task(REPORT_ACTIVITIES_STEP)
  staff_task(REVIEW_ACTIVITY_REPORT_STEP, ReviewActivityReportTask)
  staff_task(REVIEW_EXEMPTION_CLAIM_STEP, ReviewExemptionClaimTask)
  staff_task(REVIEW_DENIAL_RESPONSE_STEP, ReviewDenialResponseTask)

  # --- Start ---
  start(EXTERNAL_EXCLUSION_CHECK_STEP, on: "CertificationCreated") do |event|
    CertificationCase.new(certification_id: event[:payload][:certification_id])
  end

  # --- Transitions: External exclusion check ---
  transition(EXTERNAL_EXCLUSION_CHECK_STEP, "DeterminedNotExcluded", EXTERNAL_EXCEPTION_CHECK_STEP)
  transition(EXTERNAL_EXCLUSION_CHECK_STEP, "DeterminedExcluded", END_STEP)
  transition(EXTERNAL_EXCLUSION_CHECK_STEP, "DeterminedExcepted", END_STEP)

  # --- Transitions: External exception check ---
  # DeterminedExcepted: case ends (member need not report).
  # DeterminedNotExcepted: continue to the community-engagement check.
  transition(EXTERNAL_EXCEPTION_CHECK_STEP, "DeterminedExcepted", END_STEP)
  transition(EXTERNAL_EXCEPTION_CHECK_STEP, "DeterminedNotExcepted", EXTERNAL_COMMUNITY_ENGAGEMENT_CHECK_STEP)

  # --- Transitions: External CE check (in-hand combined hours/income) ---
  # DeterminedCommunityEngagementNotMet is an internal routing event with no
  # NotificationsEventListener subscription, so the member is not told they fell short before the
  # outbound data sources have been consulted.
  transition(EXTERNAL_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedCommunityEngagementMet", END_STEP)
  transition(EXTERNAL_COMMUNITY_ENGAGEMENT_CHECK_STEP, "DeterminedCommunityEngagementNotMet", VERIFICATION_DATA_SOURCE_CHECK_STEP)

  # --- Transitions: Verification data source check (trailing; OSCER-805) ---
  # No source produced an outcome splits two ways: Insufficient when inbound-pushed hours exist,
  # ActionRequired when none do.
  transition(VERIFICATION_DATA_SOURCE_CHECK_STEP, "DeterminedExcepted", END_STEP)
  transition(VERIFICATION_DATA_SOURCE_CHECK_STEP, "DeterminedCommunityEngagementMet", END_STEP)
  transition(VERIFICATION_DATA_SOURCE_CHECK_STEP, "DeterminedCommunityEngagementInsufficient", REPORT_ACTIVITIES_STEP)
  transition(VERIFICATION_DATA_SOURCE_CHECK_STEP, "DeterminedCommunityEngagementActionRequired", REPORT_ACTIVITIES_STEP)

  # --- Transitions: Activity report workflow ---
  # Reviewer determines compliance: approved = compliant, denied = not compliant.
  # A denial while the verification window is open returns the member to report_activities so they
  # can submit again; approval and final denial (window ended) close the case.
  transition(REPORT_ACTIVITIES_STEP, "ActivityReportApplicationFormSubmitted", REVIEW_ACTIVITY_REPORT_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "ActivityReportApproved", END_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "ActivityReportDenied", REPORT_ACTIVITIES_STEP)
  transition(REVIEW_ACTIVITY_REPORT_STEP, "ActivityReportDeniedFinal", END_STEP)

  # --- Transitions: Exemption claim workflow ---
  transition(REPORT_ACTIVITIES_STEP, "ExemptionApplicationFormSubmitted", REVIEW_EXEMPTION_CLAIM_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedExempt", END_STEP)
  transition(REVIEW_EXEMPTION_CLAIM_STEP, "DeterminedNotExempt", REPORT_ACTIVITIES_STEP)

  # --- Transitions: Denial response workflow ---
  transition(REPORT_ACTIVITIES_STEP, "DenialResponseApplicationFormSubmitted", REVIEW_DENIAL_RESPONSE_STEP)
  transition(REVIEW_DENIAL_RESPONSE_STEP, "DenialResponseApproved", END_STEP)
  transition(REVIEW_DENIAL_RESPONSE_STEP, "DenialResponseDenied", REPORT_ACTIVITIES_STEP)
  transition(REVIEW_DENIAL_RESPONSE_STEP, "DenialResponseDeniedFinal", END_STEP)
end
