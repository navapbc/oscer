# frozen_string_literal: true

# Member OIDC Controller for public member sign-in via the configured public member IdP
#
# Mirrors Auth::SsoController pattern: new (login form), callback, failure.
# Uses MemberOidcProvisioner (no role mapping). On failure redirects to member sign-in path.
#
class Auth::MemberOidcController < ApplicationController
  include OidcClaimsExtractor

  layout "sso", only: [ :new ]

  skip_before_action :verify_authenticity_token, only: [ :callback ]
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  before_action :require_member_oidc_enabled, only: [ :new ]
  before_action :redirect_if_authenticated, only: [ :new ]

  # GET /member_oidc/login
  def new
    @origin = params[:origin] || session["user_return_to"]
  end

  # GET /auth/member_oidc/callback
  def callback
    auth = request.env["omniauth.auth"]
    unless auth
      Rails.logger.warn("Member OIDC callback: missing omniauth.auth")
      redirect_to new_user_session_path, alert: t("auth.member_oidc.authentication_failed") and return
    end

    claims = extract_oidc_claims(auth, Rails.application.config.member_oidc[:claims])
    user = MemberOidcProvisioner.new.provision!(claims)
    sign_in(user)

    redirect_to after_sign_in_path_for(user), notice: t("auth.member_oidc.login_success")
  rescue ArgumentError => e
    Rails.logger.warn("Member OIDC claims error: #{e.message}")
    redirect_to new_user_session_path, alert: t("auth.member_oidc.authentication_failed")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Member OIDC provisioning failed: #{e.message}")
    redirect_to new_user_session_path, alert: t("auth.member_oidc.authentication_failed")
  end

  # GET /auth/member_oidc/failure
  def failure
    message = sanitized_failure_message(params[:message])
    Rails.logger.error("Member OIDC authentication failed: #{message}")
    redirect_to new_user_session_path, alert: t("auth.member_oidc.authentication_failed")
  end

  private

  def require_member_oidc_enabled
    return if member_oidc_enabled?

    redirect_to new_user_session_path, alert: t("auth.member_oidc.not_enabled")
  end

  def member_oidc_enabled?
    Rails.application.config.member_oidc[:enabled]
  end
end
