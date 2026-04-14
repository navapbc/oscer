# frozen_string_literal: true

class Staff::DashboardController < StaffController
  include ReportingService
  TIME_TO_CLOSE_LOOKBACK = 7.days.ago.freeze
  def index
    # TODO: Move to a scope in Strata::Task
    # Strata::Task.for_assignee(current_user.id)
    @data = {}
    if current_user.admin?
      close_seconds = time_to_close(TIME_TO_CLOSE_LOOKBACK)
      @data[:time_to_close_seconds] = close_seconds
    end
    @tasks = policy_scope(Strata::Task).pending.where(assignee_id: current_user.id)

    case_ids = @tasks.pluck(:case_id)
    @cases_by_id = certification_service.fetch_cases(case_ids).index_by(&:id)
  end
end
