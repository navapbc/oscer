# frozen_string_literal: true

module ActivityReportApplicationFormsHelper
  def activity_report_status_class(status)
    case status
    when "approved" then "text-green"
    when "denied" then "text-red"
    else ""
    end
  end

  # Per-form status for staff display: the form's own decided outcome (approved/denied) when its
  # review task has decided, otherwise the form's workflow status (in_progress/submitted). Unlike
  # +flow_status+, this reads the per-form review-task decision rather than the shared case-level
  # approval fact, so each form on a multi-form case reports its own outcome.
  def activity_report_display_status(form)
    form.approval_status || form.status
  end

  def activity_report_current_step(form, flash_notice_present:)
    if form.submitted_at.present?
      :submitted
    else
      :add_activities
    end
  end
end
