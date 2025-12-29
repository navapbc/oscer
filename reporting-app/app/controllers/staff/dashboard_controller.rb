# frozen_string_literal: true

class Staff::DashboardController < StaffController
  def index
    # TODO: Move to a scope in Strata::Task
    # Strata::Task.for_assignee(current_user.id)
    @tasks = policy_scope(Strata::Task).pending.where(assignee_id: current_user.id)

    case_ids = @tasks.pluck(:case_id)
    @cases_by_id = certification_service.fetch_cases(case_ids).index_by(&:id)
  end
end
