# frozen_string_literal: true

module StaffHelper
  def dashboard_breadcrumbs
    [
      {
        text: "Dashboard",
        link: staff_path
      }
    ]
  end

  def member_breadcrumbs(member)
    dashboard_breadcrumbs + [
      {
        text: member.name&.full_name,
        link: member_path(member.member_id)
      }
    ]
  end

  def case_breadcrumbs(member, certification_case)
    member_breadcrumbs(member) + [
      {
        text: certification_case.certification&.case_number,
        link: certification_case_path(certification_case)
      }
    ]
  end

  def task_breadcrumbs(member, certification_case, task)
    case_breadcrumbs(member, certification_case) + [
      {
        text: task.class.name.underscore.humanize,
        link: task_path(task)
      }
    ]
  end

  def time_to_close_days(data)
    precision = 2

    time_to_close_seconds = data[:time_to_close_seconds]
    return t("staff.dashboard.index.time_to_close_hours", count: 0) unless time_to_close_seconds.present?

    if time_to_close_seconds < 1.day
      t("staff.dashboard.index.time_to_close_hours", count: (time_to_close_seconds/1.hour).round(precision))
    else
      t("staff.dashboard.index.time_to_close_days", count: (time_to_close_seconds/1.day).round(precision))
    end
  end
end
