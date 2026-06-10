# frozen_string_literal: true

module DashboardHelper
  # Returns the dashboard partial to render for the member's current state.
  #
  # The three exemption-outcome partials delegate into +_member_compliance_dashboard+
  # and line up with +compliance.exemption_flow_state+ (OSCER-640):
  #
  #   "exemption_approved"  -> EXEMPTION_APPROVED       (approved request *and* the
  #                                                      automated exempt path via
  #                                                      +member_status_exempt?+)
  #   "exemption_submitted" -> EXEMPTION_PENDING_REVIEW
  #   "exemption_denied"    -> EXEMPTION_DENIED
  #
  # All other partials (no_certification, new_certification, activity_report_*) are not
  # exemption-outcome frames and keep their existing behavior.
  def determine_dashboard_view
    if member_status_exempt?
      "exemption_approved"
    elsif @certification.nil?
      "no_certification"
    elsif are_activity_report_or_exemption_incomplete?
      "new_certification"
    elsif is_activity_report_submitted?
      "activity_report_submitted"
    elsif is_activity_report_approved?
      "activity_report_approved"
    elsif is_activity_report_denied?
      "activity_report_denied"
    elsif (exemption_outcome_partial = exemption_outcome_dashboard_partial)
      exemption_outcome_partial
    else
      # Fallback for unexpected states
      "new_certification"
    end
  end

  def member_status_exempt?
    return false if @member_status.blank?
    @member_status.status == MemberStatus::EXEMPT
  end

  def application_exists?
    @activity_report_application_form.present? || @exemption_application_form.present?
  end

  def are_activity_report_or_exemption_incomplete?
    !(@activity_report_application_form&.submitted? || @exemption_application_form&.submitted?)
  end

  def is_activity_report_submitted?
    @activity_report_application_form&.submitted? && @certification_case&.activity_report_approval_status.nil?
  end

  def is_activity_report_approved?
    @activity_report_application_form&.submitted? && @certification_case&.activity_report_approval_status == "approved"
  end

  def is_activity_report_denied?
    @activity_report_application_form&.submitted? && @certification_case&.activity_report_approval_status == "denied"
  end

  # Maps +compliance.exemption_flow_state+ to the legacy dashboard partial names (OSCER-640).
  # Uses the read model so routing stays aligned when case status updates before form +flow_status+.
  def exemption_outcome_dashboard_partial
    return nil unless @member_dashboard_compliance.present?

    case @member_dashboard_compliance.exemption_flow_state
    when MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
      "exemption_submitted"
    when MemberDashboardCompliance::EXEMPTION_APPROVED
      "exemption_approved"
    when MemberDashboardCompliance::EXEMPTION_DENIED
      "exemption_denied"
    end
  end

  def should_show_submit_new_exemption_form?(certification_case)
    return false unless certification_case.present?

    certification_case.open? &&
      (certification_case.verification_window_end_date.blank? ||  certification_case.verification_window_end_date > Time.now) &&
      !ExemptionApplicationForm.has_pending_form(certification_case.id)
  end
end
