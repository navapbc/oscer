# frozen_string_literal: true

# View helpers for the member dashboard compliance UI (OSCER-337 / OSCER-480).
# Exemption dashboard UI (#640 outcome states, #641 draft). Progress cards /
# activity tables arrive in later slices (#642, #643).
module MemberComplianceHelper
  # Outcome states guarded by +guard_member_compliance_exemption_outcome_state!+.
  # +_member_compliance_exemption+ also renders +EXEMPTION_DRAFT+ (#641), which is not listed here.
  EXEMPTION_OUTCOME_FLOW_STATES = [
    MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW,
    MemberDashboardCompliance::EXEMPTION_APPROVED,
    MemberDashboardCompliance::EXEMPTION_DENIED
  ].freeze

  # Maps an exemption-history status token to the Figma badge legend variant (7203:6158).
  EXEMPTION_BADGE_VARIANTS = {
    MemberDashboardCompliance::EXEMPTION_APPROVED => "exempt",
    MemberDashboardCompliance::EXEMPTION_DENIED => "not-exempt",
    MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW => "under-review"
  }.freeze

  def member_compliance_exemption_badge_variant(status_token)
    EXEMPTION_BADGE_VARIANTS.fetch(status_token, "under-review")
  end

  def member_compliance_due_date(compliance)
    compliance.due_date && I18n.l(compliance.due_date, format: :long)
  end

  # Coverage is maintained for the month following the reporting due date (Figma 7203:5090):
  # e.g. due June 30, 2026 -> "July 2026". Pass +with_year: false+ for just the month name.
  def member_compliance_coverage_month(compliance, with_year: true)
    return nil unless compliance.due_date

    I18n.l(compliance.due_date.next_month.beginning_of_month, format: with_year ? :month_year : :month_name)
  end

  # "Exemption details" heading shows for the resolved-outcome states (approved, denied),
  # but not for the in-flight states (not started, draft, pending review) per Figma.
  def show_member_compliance_exemption_details_heading?(compliance)
    [
      MemberDashboardCompliance::EXEMPTION_NOT_STARTED,
      MemberDashboardCompliance::EXEMPTION_DRAFT,
      MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
    ].exclude?(compliance.exemption_flow_state)
  end

  def member_compliance_exemption_draft_screen?(compliance)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_DRAFT
  end

  # Draft continue returns to the exemption screener (may-qualify step when the draft
  # has an exemption type; otherwise the screener intro).
  def member_compliance_exemption_draft_continue_path(compliance)
    certification_case = compliance.certification_case
    form = compliance.exemption_application_form

    if form&.exemption_type.present?
      exemption_screener_may_qualify_path(
        exemption_type: form.exemption_type,
        certification_case_id: certification_case.id
      )
    else
      exemption_screener_path(certification_case_id: certification_case.id)
    end
  end

  def member_compliance_exemption_pending_review_screen?(compliance)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
  end

  # Figma "Get started" — exemption screener CTA before any application forms exist (7203:6175).
  def member_dashboard_get_started_screen?(compliance)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_NOT_STARTED &&
      compliance.activity_report_application_form.blank? &&
      compliance.exemption_application_form.blank?
  end

  # Label and path for the activity-report CTA on the not-exempt dashboard — mirrors
  # +_new_certification+ until the reporting section lands in #642.
  def member_compliance_activity_report_action(compliance:)
    activity_report = compliance.activity_report_application_form
    certification_case = compliance.certification_case

    if activity_report&.in_progress?
      continue_path = feature_enabled?(:doc_ai) && !session[:doc_ai_skip] ?
                        doc_ai_upload_activity_report_application_form_path(activity_report) :
                        activity_report_application_form_path(activity_report)

      {
        label: t("dashboard.member_compliance.reporting.continue_report_button"),
        path: continue_path
      }
    else
      {
        label: t("dashboard.member_compliance.reporting.start_reporting_activities_button"),
        path: new_activity_report_application_form_path(certification_case_id: certification_case&.id)
      }
    end
  end

  # Raises in test so the misrouting is caught by specs; logs a warning in every other
  # environment (development, staging, production) so a bad route is observable in production.
  def guard_member_compliance_exemption_outcome_state!(flow_state)
    return if EXEMPTION_OUTCOME_FLOW_STATES.include?(flow_state)

    message = "member_compliance_exemption partial rendered for unexpected exemption_flow_state: " \
              "#{flow_state.inspect} (expected pending_review, approved, or denied)"
    raise message if Rails.env.test?

    Rails.logger.warn(message)
  end
end
