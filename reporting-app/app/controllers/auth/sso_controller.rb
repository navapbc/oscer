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
  include OidcClaimsExtractor

  # Use minimal layout for the auto-submit form (no flash messages, headers, etc.)
  layout "sso", only: [ :new ]

  skip_before_action :verify_authenticity_token, only: [ :callback ]
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  before_action :require_sso_enabled, only: [ :new ]
  before_action :redirect_if_authenticated, only: [ :new ]

  # GET /sso/login
  # Renders a form that POSTs to OmniAuth (more secure than GET redirect)
  # Supports deep links via origin parameter
  def new
    # Pass origin to OmniAuth for deep link support
    # OmniAuth stores this and makes it available as omniauth.origin in callback
    @origin = params[:origin] || session["user_return_to"]
    # Render the SSO login form which auto-submits via POST
  end

  # GET /auth/sso/callback
  # Handles the OmniAuth callback after successful authentication
  def callback
    auth = request.env["omniauth.auth"]
    unless auth
      Rails.logger.warn("SSO callback: missing omniauth.auth")
      redirect_to root_path, alert: t("auth.sso.authentication_failed") and return
    end

    claims = extract_oidc_claims(auth, Rails.application.config.sso[:claims])
    user = provisioner.provision!(claims)
    sign_in(user)

    redirect_to after_sign_in_path_for(user), notice: t("auth.sso.login_success")
  rescue Auth::Errors::AccessDenied => e
    Rails.logger.warn("SSO access denied: #{e.message}")
    redirect_to root_path, alert: e.message
  end

  # GET /auth/failure (OmniAuth default; route points here for all strategies)
  # Staff SSO: redirect to root with auth.sso copy. Member OIDC: member sign-in + auth.member_oidc copy.
  def failure
    if params[:strategy].to_s == "member_oidc"
      message = sanitized_failure_message(params[:message])
      Rails.logger.error("Member OIDC authentication failed: #{message}")
      redirect_to new_user_session_path, alert: t("auth.member_oidc.authentication_failed")
    else
      message = sanitized_failure_message(params[:message])
      Rails.logger.error("SSO authentication failed: #{message}")
      redirect_to root_path, alert: t("auth.sso.authentication_failed")
    end
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
end
