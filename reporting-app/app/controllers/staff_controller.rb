# frozen_string_literal: true

class StaffController < Strata::StaffController
  before_action :authenticate_user!

  # TODO implement staff policy
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    # TODO: Move to a scope in Strata::Task
    # Strata::Task.for_assignee(current_user.id)
    @tasks = Strata::Task
      .pending
      .where(assignee_id: current_user.id)

    # TODO: This is inefficiently querying for the cases twice,
    # but we eventually plan on separating out Case and Task into separate aggregates.
    # Once we do that, the Task query won't automatically include the case so we can do
    # case_ids = @tasks.map(&:case_id)
    # certification_service.fetch_cases(case_ids)
    case_ids = @tasks.map(&:case).map(&:id)
    @cases_by_id = certification_service.fetch_cases(case_ids).index_by(&:id)
  end

  protected

  def header_links
    [ { name: "Search", path: search_members_path } ] + super
  end

  def case_classes
    # Add case classes in your application
    [ CertificationCase ]
  end

  private

  def certification_service
    CertificationService.new
  end
end
