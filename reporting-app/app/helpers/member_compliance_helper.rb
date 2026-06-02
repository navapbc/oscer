# frozen_string_literal: true

module MemberComplianceHelper
  EXEMPTION_ALERT_VARIANTS = {
    MemberDashboardCompliance::EXEMPTION_NOT_STARTED => "info",
    MemberDashboardCompliance::EXEMPTION_DRAFT => "info",
    MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW => "info",
    MemberDashboardCompliance::EXEMPTION_APPROVED => "success",
    MemberDashboardCompliance::EXEMPTION_DENIED => "error"
  }.freeze

  REPORT_STATUS_VARIANTS = {
    MemberStatus::DASHBOARD_REPORT_IN_PROGRESS => "in-progress",
    MemberStatus::DASHBOARD_REPORT_UNDER_REVIEW => "under-review",
    MemberStatus::DASHBOARD_REPORT_COMPLIANT => "compliant",
    MemberStatus::DASHBOARD_REPORT_NOT_COMPLIANT => "not-compliant",
    MemberStatus::DASHBOARD_REPORT_EXEMPT => "exempt"
  }.freeze

  EXEMPTION_BADGE_VARIANTS = {
    MemberDashboardCompliance::EXEMPTION_APPROVED => "exempt",
    MemberDashboardCompliance::EXEMPTION_DENIED => "not-exempt",
    MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW => "under-review"
  }.freeze

  # Progress cards: income uses continuous lookback (period_start_on → period_end_on);
  # hours-only cards use certification_date → due_date (Figma short uppercase, e.g. "JUN-AUG 2026").
  def member_compliance_period_label(compliance)
    if compliance.show_income_summary && compliance.period_start_on && compliance.period_end_on
      format_period_range(compliance.period_start_on, compliance.period_end_on)
    elsif compliance.certification_date
      format_period_range(compliance.certification_date, compliance.due_date || compliance.certification_date)
    end
  end

  # Activity table heading: long month from certification_date (Figma, e.g. "August 2026 Activity Report").
  def member_compliance_activity_report_title(compliance)
    period_label = compliance.certification_date && I18n.l(compliance.certification_date, format: :month_year)
    t("dashboard.member_compliance.activity_report_title", period: period_label)
  end

  def member_compliance_due_date(compliance)
    compliance.due_date && I18n.l(compliance.due_date, format: :long)
  end

  # Coverage is maintained for the month following the reporting due date (Figma 7203:5090 / frame 2):
  # e.g. due June 30, 2026 → "July 2026". Pass +with_year: false+ for just the month name ("July").
  def member_compliance_coverage_month(compliance, with_year: true)
    return nil unless compliance.due_date

    I18n.l(compliance.due_date.next_month.beginning_of_month, format: with_year ? :month_year : :month_name)
  end

  # Dashboard copy for progress cards — may show "in progress" before the due date while the
  # member is still editing an unsubmitted report, even when determination outcome is not_compliant.
  def member_compliance_dashboard_report_status_token(compliance, activity_report: nil)
    if member_compliance_editable_activity_report?(compliance, activity_report:)
      MemberStatus::DASHBOARD_REPORT_IN_PROGRESS
    else
      compliance.report_status_token
    end
  end

  def member_compliance_reporting_period_open?(compliance)
    compliance.due_date.blank? || Date.current <= compliance.due_date
  end

  def member_compliance_editable_activity_report?(compliance, activity_report:)
    activity_report.present? &&
      !activity_report.submitted? &&
      member_compliance_reporting_period_open?(compliance)
  end

  def member_compliance_report_status_subcopy(compliance, activity_report: nil)
    status_key = member_compliance_dashboard_report_status_token(compliance, activity_report:).tr("-", "_")
    t(
      "dashboard.member_compliance.progress_cards.report_status_subcopy.#{status_key}",
      due_date: member_compliance_due_date(compliance),
      default: ""
    )
  end

  def member_compliance_exemption_alert_variant(compliance)
    EXEMPTION_ALERT_VARIANTS.fetch(compliance.exemption_flow_state, "info")
  end

  def member_compliance_report_status_variant(compliance, activity_report: nil)
    token = member_compliance_dashboard_report_status_token(compliance, activity_report:)
    REPORT_STATUS_VARIANTS.fetch(token, "in-progress")
  end

  # Figma income path: yellow fill while reporting is in progress and income is below target.
  def member_compliance_income_reported_progress_modifier(compliance, activity_report: nil)
    return nil unless compliance.show_income_summary

    member_compliance_reported_progress_modifier(
      compliance.income_percent_of_requirement.to_f,
      member_compliance_dashboard_report_status_token(compliance, activity_report:)
    )
  end

  # Hours-path parallel to +member_compliance_income_reported_progress_modifier+: yellow fill
  # while reporting is in progress and hours are below target, green once the target is met.
  def member_compliance_hours_reported_progress_modifier(compliance, activity_report: nil)
    return nil if compliance.show_income_summary

    member_compliance_reported_progress_modifier(
      compliance.hours_percent_of_requirement.to_f,
      member_compliance_dashboard_report_status_token(compliance, activity_report:)
    )
  end

  def member_compliance_exemption_badge_variant(status_token)
    EXEMPTION_BADGE_VARIANTS.fetch(status_token, "under-review")
  end

  def member_compliance_source_label(source_token)
    case source_token
    when MemberDashboardCompliance::SOURCE_EXTERNAL_CE
      t("certification_cases.common.source_external", state_name: state_name)
    when MemberDashboardCompliance::SOURCE_SELF_REPORTED
      t("certification_cases.common.source_self_reported")
    else
      t("dashboard.member_compliance.source.unknown", default: source_token.to_s.humanize)
    end
  end

  # Continue / submit CTAs while the reporting period is open and the activity report is unsubmitted.
  def show_member_compliance_activity_report_actions?(compliance, activity_report: nil)
    member_compliance_editable_activity_report?(compliance, activity_report:)
  end

  def member_compliance_hours_only_screen?(compliance)
    !compliance.show_income_summary
  end

  def member_compliance_reporting_continue_button_label(compliance)
    if member_compliance_hours_only_screen?(compliance)
      t("dashboard.member_compliance.reporting.continue_reporting_button")
    else
      t("dashboard.member_compliance.reporting.continue_button")
    end
  end

  # Figma income path with activity report in progress (7203:4779 — four cards + table).
  def member_compliance_income_reporting_in_progress_screen?(compliance, activity_report:)
    compliance.show_income_summary &&
      activity_report.present? &&
      show_member_compliance_activity_report_actions?(compliance, activity_report:)
  end

  # Four progress cards on both the income and hours paths (the hours path now mirrors income),
  # so cards span a quarter width on desktop.
  def member_compliance_progress_card_column_class
    "grid-col-12 tablet:grid-col-6 desktop:grid-col-3"
  end

  def show_member_compliance_exemption_details_heading?(compliance)
    [
      MemberDashboardCompliance::EXEMPTION_NOT_STARTED,
      MemberDashboardCompliance::EXEMPTION_DRAFT,
      MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
    ].exclude?(compliance.exemption_flow_state)
  end

  # Figma "Get started" — exemption screener CTA before any activity report exists.
  def member_compliance_get_started_screen?(compliance, activity_report:)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_NOT_STARTED &&
      activity_report.blank?
  end

  # Figma "Exemption draft in progress" — continue draft request (7203:5214).
  def member_compliance_exemption_draft_screen?(compliance)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_DRAFT
  end

  def member_compliance_exemption_pending_review_screen?(compliance)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
  end

  def member_compliance_exemption_approved_screen?(compliance)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_APPROVED
  end

  def member_compliance_exemption_denied_screen?(compliance)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_DENIED
  end

  # Figma: red alert on income path; yellow on hours-only (frame 7203:4806).
  def member_compliance_exemption_denied_alert_variant(compliance)
    compliance.show_income_summary ? "error" : "warning"
  end

  # Not exempt, no activity report yet — intro + Start reporting activities (7203:5090).
  def member_compliance_start_reporting_screen?(compliance, activity_report:)
    member_compliance_exemption_denied_screen?(compliance) && activity_report.blank?
  end

  def show_member_compliance_retake_screener?(compliance)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_DENIED
  end

  def show_member_compliance_reporting_section?(compliance, activity_report:)
    return false if compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_APPROVED
    return false if compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_DRAFT
    return false if compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
    return false if compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_NOT_STARTED && activity_report.blank?

    true
  end

  def show_member_compliance_progress_cards?(compliance, activity_report:)
    show_member_compliance_reporting_section?(compliance, activity_report:) && activity_report.present?
  end

  def show_member_compliance_income_table?(compliance, activity_report:)
    show_member_compliance_progress_cards?(compliance, activity_report:) && compliance.show_income_summary
  end

  def show_member_compliance_hours_table?(compliance, activity_report:)
    show_member_compliance_progress_cards?(compliance, activity_report:) && !compliance.show_income_summary
  end

  def format_period_range(start_date, end_date)
    start_month = start_date.strftime("%b").upcase
    end_month = end_date.strftime("%b").upcase
    year = end_date.year

    if start_date.year == end_date.year && start_date.month == end_date.month
      "#{start_month} #{year}"
    else
      "#{start_month}-#{end_month} #{year}"
    end
  end

  private

  def member_compliance_reported_progress_modifier(percent, token)
    if token == MemberStatus::DASHBOARD_REPORT_IN_PROGRESS && percent < 100
      "warning"
    elsif percent >= 100
      "compliant"
    end
  end
end
