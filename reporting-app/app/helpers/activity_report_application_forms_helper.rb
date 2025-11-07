# frozen_string_literal: true

module ActivityReportApplicationFormsHelper
  def activity_report_status_class(status)
    status == "approved" ? "text-green" : "text-red"
  end

  def activity_report_current_step(form, flash_notice_present:)
    return nil if form.submitted_at.present? && !flash_notice_present

    if flash_notice_present && form.submitted_at.present?
      :submitted
    else
      :add_activities
    end
  end

  def activity_type_display(activity)
    case activity.class.name
    when "IncomeActivity"
      "Income"
    when "WorkActivity"
      "Hourly Work"
    else
      activity.type.humanize
    end
  end
end
