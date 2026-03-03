# frozen_string_literal: true

# Not to be confused with a "benefits application" or "claim".
# This is the parent class for all other controllers in the application.
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include FeatureFlagHelper

  helper_method :feature_enabled?

  around_action :switch_locale
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  # Set the active locale based on the URL
  # For example, if the URL starts with /es-US, the locale will be set to :es-US
  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  # After a user signs in, Devise uses this method to determine where to route them
  # Supports deep links - returns user to the page they were trying to access
  def after_sign_in_path_for(resource)
    unless resource.is_a?(User)
      raise "Unexpected resource type"
    end

    # Determine the final return path (before any redirects)
    return_path = safe_return_path(request.env["omniauth.origin"]) ||
                  safe_return_path(stored_location_for(resource)) ||
                  safe_return_path(session.delete("user_return_to")) ||
                  safe_return_path(session["post_login_redirect"]) ||
                  dashboard_path

    if resource.mfa_preference.nil?
      # Store return path for after MFA setup
      session["post_login_redirect"] = return_path
      return users_mfa_preference_path
    end

    # Clear and return the stored path
    session.delete("post_login_redirect")
    return_path
  end

  private

  # Validates return paths to prevent open redirect vulnerabilities
  # Only allows relative paths within the application
  def safe_return_path(path)
    return nil if path.blank?
    return nil unless path.start_with?("/")  # Must be relative path
    return nil if path.start_with?("//")     # Prevent protocol-relative URLs
    return nil if path.include?("://")       # Prevent absolute URLs embedded in path

    path
  end

  def show_detailed_exceptions?
    Rails.application.config.respond_to?(:consider_all_non_api_requests_local) && Rails.application.config.consider_all_non_api_requests_local
  end
end
