# frozen_string_literal: true

module MemberComplianceHelper
  # Figma "Get started" — exemption screener CTA before any activity report exists (7203:6175).
  def member_compliance_get_started_screen?(compliance, activity_report:)
    compliance.exemption_flow_state == MemberDashboardCompliance::EXEMPTION_NOT_STARTED &&
      activity_report.blank?
  end
end
