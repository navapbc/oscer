# frozen_string_literal: true

# Helper module for SSO functionality in views
module SsoHelper
  # Check if SSO is enabled for the application
  # @return [Boolean] true if SSO is enabled via configuration
  def sso_enabled?
    Rails.application.config.sso[:enabled] == true
  rescue NoMethodError
    # SSO config not loaded (e.g., in tests without SSO setup)
    false
  end

  # Public member IdP sign-in (member OIDC). See docs/architecture/staff-sso/member-sso.md
  def member_oidc_enabled?
    Rails.application.config.member_oidc[:enabled] == true
  rescue NoMethodError
    false
  end

  # When true, member sign-in URL redirects to member OIDC (no Cognito email/password on that page).
  def member_oidc_member_auth_only?
    return false unless member_oidc_enabled?

    Rails.application.config.member_oidc[:member_auth_only] == true
  rescue NoMethodError
    false
  end
end
