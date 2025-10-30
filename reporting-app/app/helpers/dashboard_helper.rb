# frozen_string_literal: true

module DashboardHelper
  def determine_dashboard_view
    if @certification.nil?
      "no_certification"
    elsif are_activity_report_or_exemption_incomplete?
      "new_certification"
    elsif is_activity_report_submitted?
      "activity_report_submitted"
    elsif is_activity_report_approved?
      "activity_report_approved"
    elsif is_activity_report_denied?
      "activity_report_denied"
    elsif is_exemption_request_submitted?
      "exemption_submitted"
    elsif is_exemption_request_approved?
      "exemption_approved"
    elsif is_exemption_request_denied?
      "exemption_denied"
    else
      # Fallback for unexpected states
      "new_certification"
    end
  end

  def are_activity_report_or_exemption_incomplete?
    !(@activity_report_application_form&.submitted? || @exemption_application_form&.submitted?)
  end

  def is_activity_report_submitted?
    @activity_report_application_form&.submitted? && @certification_case&.activity_report_approval_status.nil?
  end

  def is_exemption_request_submitted?
    @exemption_application_form&.submitted? && @certification_case&.exemption_request_approval_status.nil?
  end

  def is_activity_report_approved?
    @activity_report_application_form&.submitted? && @certification_case&.activity_report_approval_status == "approved"
  end

  def is_exemption_request_approved?
    @exemption_application_form&.submitted? && @certification_case&.exemption_request_approval_status == "approved"
  end

  def is_activity_report_denied?
    @activity_report_application_form&.submitted? && @certification_case&.activity_report_approval_status == "denied"
  end

  def is_exemption_request_denied?
    @exemption_application_form&.submitted? && @certification_case&.exemption_request_approval_status == "denied"
  end
end
