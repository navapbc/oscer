# frozen_string_literal: true

class StaffController < Strata::StaffController
  class_attribute :authorization_resource, default: :staff

  before_action :authenticate_user!
  before_action :authorize_staff_access
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  helper_method :header_links

  def header_links
    batch_uploads_link = policy(CertificationBatchUpload).index? ? [ { name: "Batch Uploads", path: certification_batch_uploads_path } ] : []
    organization_settings_link = policy(:admin).index? ? [ { name: "Organization Settings", path: users_path } ] : []
    tasks_link = [ { name: "Tasks", path: "/staff/tasks" } ]
    cases_link = [ { name: "Certification Cases", path: certification_cases_path } ]
    [
      { name: "Search", path: search_members_path }
    ] + batch_uploads_link + cases_link + tasks_link + organization_settings_link
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
