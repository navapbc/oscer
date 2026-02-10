# frozen_string_literal: true

# SSO Controller for Staff Single Sign-On via OIDC
#
# Handles the OIDC authorization code flow:
# 1. new: Initiates login by redirecting to IdP with state/nonce
# 2. callback: Exchanges code for tokens, provisions user, creates session
# 3. destroy: Logs out the user (local logout only)
#
# Security:
# - State parameter prevents CSRF attacks
# - Nonce parameter prevents replay attacks
# - Secure comparison prevents timing attacks
#
class Auth::SsoController < ApplicationController
  # IdP redirects to callback via GET request, so no CSRF token is available
  skip_before_action :verify_authenticity_token, only: [ :callback ]
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  before_action :require_sso_enabled, except: [ :destroy ]
  before_action :redirect_if_authenticated, only: [ :new ]

  # GET /auth/sso
  # Initiates SSO login by redirecting to the Identity Provider
  def new
    state = SecureRandom.hex(32)
    nonce = SecureRandom.hex(32)

    session[:sso_state] = state
    session[:sso_nonce] = nonce

    redirect_to oidc_client.authorization_url(state: state, nonce: nonce),
                allow_other_host: true
  end

  # GET /auth/sso/callback
  # Handles the IdP callback after authentication
  def callback
    # Handle OAuth error responses (e.g., user denied consent)
    if params[:error].present?
      Rails.logger.warn("SSO error from IdP: #{params[:error]} - #{params[:error_description]}")
      return redirect_to root_path, alert: t("auth.sso.authentication_failed")
    end

    verify_state!
    nonce = session[:sso_nonce]
    clear_sso_session

    tokens = oidc_client.exchange_code(code: params[:code])
    claims = oidc_client.extract_claims(tokens["id_token"], expected_nonce: nonce)

    user = provisioner.provision!(claims)
    sign_in(user)

    redirect_to after_sign_in_path_for(user), notice: t("auth.sso.login_success")
  rescue OidcClient::TokenExchangeError, OidcClient::TokenValidationError => e
    Rails.logger.error("SSO authentication failed: #{e.message}")
    redirect_to root_path, alert: t("auth.sso.authentication_failed")
  rescue Auth::Errors::AccessDenied => e
    Rails.logger.warn("SSO access denied: #{e.message}")
    redirect_to root_path, alert: e.message
  end

  # DELETE /auth/sso/logout
  # Logs out the user (local logout only, does not redirect to IdP)
  def destroy
    sign_out(current_user) if current_user
    redirect_to root_path, notice: t("auth.sso.logout_success")
  end

  private

  def oidc_client
    @oidc_client ||= OidcClient.new
  end

  def provisioner
    @provisioner ||= StaffUserProvisioner.new
  end

  def require_sso_enabled
    return if oidc_client.enabled?

    redirect_to root_path, alert: t("auth.sso.not_enabled")
  end

  def redirect_if_authenticated
    return unless user_signed_in?

    redirect_to after_sign_in_path_for(current_user)
  end

  def verify_state!
    expected_state = session[:sso_state].to_s
    received_state = params[:state].to_s

    return if expected_state.present? && ActiveSupport::SecurityUtils.secure_compare(expected_state, received_state)

    clear_sso_session
    raise OidcClient::TokenValidationError, "Invalid state parameter"
  end

  def clear_sso_session
    session.delete(:sso_state)
    session.delete(:sso_nonce)
  end
end
