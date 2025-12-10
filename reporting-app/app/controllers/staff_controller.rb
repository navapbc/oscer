# frozen_string_literal: true

class StaffController < Strata::StaffController
  class_attribute :authorization_resource, default: :staff

  before_action :authenticate_user!
  before_action :authorize_staff_access
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def index
    # TODO: Move to a scope in Strata::Task
    # Strata::Task.for_assignee(current_user.id)
    @tasks = policy_scope(
      Strata::Task
        .pending
        .where(assignee_id: current_user.id)
    )

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
    batch_uploads_link = policy(CertificationBatchUpload).index? ? [ { name: "Batch Uploads", path: certification_batch_uploads_path } ] : []
    organization_settings_link = policy(:admin).index? ? [ { name: "Organization Settings", path: users_path } ] : []
    [
      { name: "Search", path: search_members_path }
    ] + batch_uploads_link + super + organization_settings_link
  end

  def case_classes
    # Add case classes in your application
    [ CertificationCase ]
  end

  private

  def authorize_staff_access
    authorize authorization_resource
  end

  def certification_service
    CertificationService.new
  end

  def user_not_authorized
    # TODO: render unauthorized template in follow-up PR
    if policy(:staff).index?
      redirect_to staff_path
      return
    end

    redirect_to dashboard_path
  end
end
