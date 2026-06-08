# frozen_string_literal: true

# View helpers for the member dashboard compliance UI (OSCER-337 / OSCER-480).
# This slice (#640) covers the exemption outcome states: exempt, under review,
# and does not qualify. Reporting/progress-card helpers arrive in later slices.
module MemberComplianceHelper
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

  def member_compliance_exemption_pending_review_screen?(compliance)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
  end
end
