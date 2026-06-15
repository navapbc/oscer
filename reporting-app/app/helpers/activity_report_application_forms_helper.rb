# frozen_string_literal: true

module ActivityReportApplicationFormsHelper
  def activity_report_status_class(status)
    case status
    when "approved" then "text-green"
    when "denied" then "text-red"
    else ""
    end
  end

  def activity_report_current_step(form, flash_notice_present:)
    if form.submitted_at.present?
      :submitted
    else
      :add_activities
    end
  end
end
