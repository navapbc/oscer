# frozen_string_literal: true

# SSO Controller for Staff Single Sign-On via OIDC
#
# Uses OmniAuth to handle the OIDC authorization code flow.
# OmniAuth automatically handles:
# - Authorization URL generation with state/nonce
# - Token exchange
# - ID token validation
#
# This controller only handles:
# - Provisioning users from OmniAuth auth hash
# - Session management
# - Error handling
#
class Auth::SsoController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :callback ]
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  before_action :require_sso_enabled, only: [ :new ]
  before_action :redirect_if_authenticated, only: [ :new ]

  # GET /sso/login
  # Initiates SSO login by redirecting to OmniAuth request phase
  # Supports deep links via origin parameter
  def new
    # Pass origin to OmniAuth for deep link support
    # OmniAuth stores this and makes it available as omniauth.origin in callback
    origin = params[:origin] || stored_location_for(:user)

    if origin.present?
      redirect_to "/auth/sso?origin=#{CGI.escape(origin)}", allow_other_host: true
    else
      redirect_to "/auth/sso", allow_other_host: true
    end
  end

  # GET /auth/sso/callback
  # Handles the OmniAuth callback after successful authentication
  def callback
    auth = request.env["omniauth.auth"]

    claims = extract_claims(auth)
    user = provisioner.provision!(claims)
    sign_in(user)

    redirect_to after_sign_in_path_for(user), notice: t("auth.sso.login_success")
  rescue Auth::Errors::AccessDenied => e
    Rails.logger.warn("SSO access denied: #{e.message}")
    redirect_to root_path, alert: e.message
  end

  # GET /auth/sso/failure
  # Handles OmniAuth authentication failures
  def failure
    message = params[:message] || "unknown_error"
    Rails.logger.error("SSO authentication failed: #{message}")
    redirect_to root_path, alert: t("auth.sso.authentication_failed")
  end

  # DELETE /auth/sso/logout
  # Logs out the user (local logout only, does not redirect to IdP)
  def destroy
    sign_out(current_user) if current_user
    redirect_to root_path, notice: t("auth.sso.logout_success")
  end

  private

  def provisioner
    @provisioner ||= StaffUserProvisioner.new
  end

  def require_sso_enabled
    return if sso_enabled?

    redirect_to root_path, alert: t("auth.sso.not_enabled")
  end

  def sso_enabled?
    Rails.application.config.sso[:enabled]
  end

  def redirect_if_authenticated
    return unless user_signed_in?

    redirect_to after_sign_in_path_for(current_user)
  end

  # Extract claims from OmniAuth auth hash using configured claim names
  def extract_claims(auth)
    claim_config = Rails.application.config.sso[:claims]
    raw_info = auth.extra.raw_info

    {
      uid: auth.uid,
      email: raw_info[claim_config[:email]],
      name: raw_info[claim_config[:name]],
      groups: Array(raw_info[claim_config[:groups]])
    }
  end
end
