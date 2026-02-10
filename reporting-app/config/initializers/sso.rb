# frozen_string_literal: true

# SSO Configuration for Staff Single Sign-On via OIDC
#
# Uses OmniAuth with OpenID Connect strategy for authentication.
# Each deployment can use a different identity provider by changing env vars.
#
# Required environment variables (when SSO_ENABLED=true):
#   SSO_ISSUER_URL     - IdP issuer URL (e.g., https://login.microsoftonline.com/{tenant}/v2.0)
#   SSO_CLIENT_ID      - OIDC client ID from IdP app registration
#   SSO_CLIENT_SECRET  - OIDC client secret from IdP app registration
#
# Optional environment variables:
#   SSO_SCOPES         - Space-separated scopes (default: "openid profile email")
#   SSO_CLAIM_EMAIL    - Claim name for email (default: "email")
#   SSO_CLAIM_NAME     - Claim name for display name (default: "name")
#   SSO_CLAIM_GROUPS   - Claim name for group membership (default: "groups")
#   SSO_CLAIM_UID      - Claim name for unique identifier (default: "sub")

# Store config for use in views/helpers
Rails.application.config.sso = {
  enabled: ENV.fetch("SSO_ENABLED", "false") == "true",
  claims: {
    email: ENV.fetch("SSO_CLAIM_EMAIL", "email"),
    name: ENV.fetch("SSO_CLAIM_NAME", "name"),
    groups: ENV.fetch("SSO_CLAIM_GROUPS", "groups"),
    unique_id: ENV.fetch("SSO_CLAIM_UID", "sub")
  }
}.freeze

# Configure OmniAuth OpenID Connect strategy
if Rails.application.config.sso[:enabled]
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :openid_connect,
      name: :sso,
      issuer: ENV.fetch("SSO_ISSUER_URL"),
      scope: ENV.fetch("SSO_SCOPES", "openid profile email").split,
      response_type: :code,
      client_options: {
        identifier: ENV.fetch("SSO_CLIENT_ID"),
        secret: ENV.fetch("SSO_CLIENT_SECRET"),
        redirect_uri: "http://#{ENV.fetch('APP_HOST', 'localhost')}:#{ENV.fetch('APP_PORT', '3000')}/auth/sso/callback"
      }
  end
end

# OmniAuth configuration
OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = [ :post, :get ]
