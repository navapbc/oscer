# frozen_string_literal: true

# SSO Configuration for Staff Single Sign-On via OIDC
#
# This initializer sets up the SSO configuration from environment variables.
# Each deployment can use a different identity provider by changing env vars.
#
# Required environment variables (when SSO_ENABLED=true):
#   SSO_ISSUER_URL     - IdP base URL (e.g., https://login.microsoftonline.com/{tenant}/v2.0)
#   SSO_CLIENT_ID      - OIDC client ID from IdP app registration
#   SSO_CLIENT_SECRET  - OIDC client secret from IdP app registration
#   SSO_REDIRECT_URI   - Callback URL (e.g., https://app.example.com/auth/sso/callback)
#
# Optional environment variables:
#   SSO_DISCOVERY_URL  - Internal URL for OIDC discovery (default: SSO_ISSUER_URL)
#                        Use when app container can't reach IdP via same URL as browser
#                        (e.g., host.docker.internal:8080 instead of localhost:8080)
#   SSO_CLAIM_EMAIL    - Claim name for email (default: "email")
#   SSO_CLAIM_NAME     - Claim name for display name (default: "name")
#   SSO_CLAIM_GROUPS   - Claim name for group membership (default: "groups")
#   SSO_CLAIM_UID      - Claim name for unique identifier (default: "sub")

Rails.application.config.sso = {
  # Feature flag - SSO is disabled by default
  enabled: ENV.fetch("SSO_ENABLED", "false") == "true",

  # Identity Provider configuration
  issuer: ENV.fetch("SSO_ISSUER_URL", nil),
  discovery_url: ENV.fetch("SSO_DISCOVERY_URL", nil) || ENV.fetch("SSO_ISSUER_URL", nil),
  client_id: ENV.fetch("SSO_CLIENT_ID", nil),
  client_secret: ENV.fetch("SSO_CLIENT_SECRET", nil),
  redirect_uri: ENV.fetch("SSO_REDIRECT_URI", nil),

  # OIDC scopes to request
  # Note: 'groups' scope must be configured in IdP; Keycloak needs a custom scope/mapper
  scopes: ENV.fetch("SSO_SCOPES", "openid profile email").split,

  # Claim name mappings (different IdPs may use different claim names)
  claims: {
    email: ENV.fetch("SSO_CLAIM_EMAIL", "email"),
    name: ENV.fetch("SSO_CLAIM_NAME", "name"),
    groups: ENV.fetch("SSO_CLAIM_GROUPS", "groups"),
    unique_id: ENV.fetch("SSO_CLAIM_UID", "sub")
  }
}.freeze
