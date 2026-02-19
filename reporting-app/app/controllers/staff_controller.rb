# frozen_string_literal: true

class StaffController < Strata::StaffController
  class_attribute :authorization_resource, default: :staff

  before_action :authenticate_staff!
  before_action :authorize_staff_access
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

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

  # Custom authentication for staff that redirects to SSO if enabled
  def authenticate_staff!
    return if user_signed_in?

    # Store the requested URL for redirect after login
    store_location_for(:user, request.fullpath)

    # Staff users go directly to SSO if enabled
    if sso_enabled?
      redirect_to sso_login_path
    else
      redirect_to new_user_session_path
    end
  end

  def authorize_staff_access
    authorize authorization_resource
  end

  def certification_service
    CertificationService.new
  end

  def user_not_authorized
    # User is authenticated but not authorized for this staff action
    # This can happen if a non-staff user somehow reaches a staff URL
    if user_signed_in? && policy(:staff).index?
      redirect_to staff_path
      return
    end

    # Non-staff users go to their dashboard
    redirect_to dashboard_path
  end

  def sso_enabled?
    Rails.application.config.sso[:enabled] == true
  rescue NoMethodError
    false
  end
end
