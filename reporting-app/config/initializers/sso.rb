# frozen_string_literal: true

# Build OIDC redirect URI with correct scheme, host, port, and path.
# Used by both staff SSO and member OIDC.
# Defaults to HTTPS (production assumption) unless DISABLE_HTTPS=true (e.g. local dev).
#
# @param path [String] Callback path (e.g. "/auth/sso/callback" or "/auth/member_oidc/callback")
# @return [String] Full redirect URI
def build_oidc_redirect_uri(path)
  host = ENV.fetch("APP_HOST", "localhost")
  port = ENV.fetch("APP_PORT", "443")
  https_disabled = ENV.fetch("DISABLE_HTTPS", "false") == "true"

  scheme = https_disabled ? "http" : "https"
  standard_port = https_disabled ? "80" : "443"
  port_suffix = (port == standard_port) ? "" : ":#{port}"
  path = path.start_with?("/") ? path : "/#{path}"

  "#{scheme}://#{host}#{port_suffix}#{path}"
end

# SSO Configuration for Staff Single Sign-On via OIDC
#
# Required environment variables (when SSO_ENABLED=true):
#   SSO_ISSUER_URL     - IdP issuer URL (e.g., https://login.microsoftonline.com/{tenant}/v2.0)
#   SSO_CLIENT_ID      - OIDC client ID
#   SSO_CLIENT_SECRET  - OIDC client secret (use "unused" for public clients)
#
# Optional:
#   SSO_SCOPES         - Space-separated scopes (default: "openid profile email")
#   SSO_INTERNAL_HOST  - Override hostname for API calls (Docker networking)

Rails.application.config.sso = {
  enabled: ENV.fetch("SSO_ENABLED", "false") == "true",
  claims: {
    email: ENV.fetch("SSO_CLAIM_EMAIL", "email"),
    name: ENV.fetch("SSO_CLAIM_NAME", "name"),
    groups: ENV.fetch("SSO_CLAIM_GROUPS", "groups"),
    unique_id: ENV.fetch("SSO_CLAIM_UID", "sub"),
    region: ENV.fetch("SSO_CLAIM_REGION", "custom:region")
  }
}.freeze

# Member OIDC Configuration (citizen IdP sign-in)
#
# Required environment variables (when MEMBER_OIDC_ENABLED=true):
#   MEMBER_OIDC_ISSUER_URL     - Citizen IdP issuer URL
#   MEMBER_OIDC_CLIENT_ID      - OIDC client ID
#   MEMBER_OIDC_CLIENT_SECRET  - OIDC client secret
#
# Optional:
#   MEMBER_OIDC_SCOPES         - Space-separated scopes (default: "openid profile email")
#   MEMBER_OIDC_INTERNAL_HOST  - Override hostname for server-to-IdP calls (Docker)
#   MEMBER_OIDC_CLAIM_EMAIL    - Claim key for email (default: "email")
#   MEMBER_OIDC_CLAIM_NAME     - Claim key for name (default: "name")
#   MEMBER_OIDC_CLAIM_UID     - Claim key for unique id (default: "sub")
#   MEMBER_OIDC_MEMBER_AUTH_ONLY - When true with MEMBER_OIDC_ENABLED, unauthenticated visits to
#                                  the member sign-in page redirect to the member OIDC flow (no email/password form).

Rails.application.config.member_oidc = {
  enabled: ENV.fetch("MEMBER_OIDC_ENABLED", "false") == "true",
  member_auth_only: ENV.fetch("MEMBER_OIDC_MEMBER_AUTH_ONLY", "false") == "true",
  claims: {
    email: ENV.fetch("MEMBER_OIDC_CLAIM_EMAIL", "email"),
    name: ENV.fetch("MEMBER_OIDC_CLAIM_NAME", "name"),
    unique_id: ENV.fetch("MEMBER_OIDC_CLAIM_UID", "sub")
  }
}.freeze

# Register OmniAuth OIDC provider(s)
staff_sso_enabled = Rails.application.config.sso[:enabled] || Rails.env.test?
member_oidc_enabled = Rails.application.config.member_oidc[:enabled] || Rails.env.test?

if staff_sso_enabled
  issuer_url = ENV.fetch("SSO_ISSUER_URL", "https://test-idp.example.com")
  issuer_uri = URI.parse(issuer_url)
  use_http = issuer_url.start_with?("http://")

  internal_host = ENV.fetch("SSO_INTERNAL_HOST") { issuer_uri.host }
  internal_base = "#{issuer_uri.scheme}://#{internal_host}:#{issuer_uri.port}#{issuer_uri.path}"

  Rails.application.config.middleware.use OmniAuth::Builder do
    provider_options = {
      name: :sso,
      issuer: issuer_url,
      scope: ENV.fetch("SSO_SCOPES", "openid profile email").split,
      response_type: :code,
      discovery: !use_http,
      client_options: {
        identifier: ENV.fetch("SSO_CLIENT_ID", "test-client"),
        secret: ENV.fetch("SSO_CLIENT_SECRET", "test-secret"),
        redirect_uri: build_oidc_redirect_uri("/auth/sso/callback")
      }
    }

    if use_http
      provider_options[:client_options].merge!(
        authorization_endpoint: "#{internal_base}/protocol/openid-connect/auth",
        token_endpoint: "#{internal_base}/protocol/openid-connect/token",
        userinfo_endpoint: "#{internal_base}/protocol/openid-connect/userinfo",
        jwks_uri: "#{internal_base}/protocol/openid-connect/certs"
      )
    end

    provider :openid_connect, **provider_options
  end
end

if member_oidc_enabled
  member_issuer_url = Rails.env.test? ? ENV.fetch("MEMBER_OIDC_ISSUER_URL", "https://test-member-idp.example.com") : ENV.fetch("MEMBER_OIDC_ISSUER_URL")
  member_issuer_uri = URI.parse(member_issuer_url)
  member_use_http = member_issuer_url.start_with?("http://")

  member_internal_host = ENV.fetch("MEMBER_OIDC_INTERNAL_HOST") { member_issuer_uri.host }
  member_internal_base = "#{member_issuer_uri.scheme}://#{member_internal_host}:#{member_issuer_uri.port}#{member_issuer_uri.path}"

  Rails.application.config.middleware.use OmniAuth::Builder do
    member_provider_options = {
      name: :member_oidc,
      issuer: member_issuer_url,
      scope: ENV.fetch("MEMBER_OIDC_SCOPES", "openid profile email").split,
      response_type: :code,
      discovery: !member_use_http,
      client_options: {
        identifier: Rails.env.test? ? ENV.fetch("MEMBER_OIDC_CLIENT_ID", "test-member-client") : ENV.fetch("MEMBER_OIDC_CLIENT_ID"),
        secret: Rails.env.test? ? ENV.fetch("MEMBER_OIDC_CLIENT_SECRET", "test-member-secret") : ENV.fetch("MEMBER_OIDC_CLIENT_SECRET"),
        redirect_uri: build_oidc_redirect_uri("/auth/member_oidc/callback")
      }
    }

    if member_use_http
      member_provider_options[:client_options].merge!(
        authorization_endpoint: "#{member_internal_base}/protocol/openid-connect/auth",
        token_endpoint: "#{member_internal_base}/protocol/openid-connect/token",
        userinfo_endpoint: "#{member_internal_base}/protocol/openid-connect/userinfo",
        jwks_uri: "#{member_internal_base}/protocol/openid-connect/certs"
      )
    end

    provider :openid_connect, **member_provider_options
  end
end

# OmniAuth configuration (shared)
OmniAuth.config.logger = Rails.logger
# Only allow POST for security (CVE-2015-9284)
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.request_validation_phase = nil

# WORKAROUND: Skip issuer verification for local HTTP development
# Applies when SSO_ISSUER_URL or MEMBER_OIDC_ISSUER_URL is http:// (e.g. local Keycloak)
if Rails.env.development? &&
   (ENV.fetch("SSO_ISSUER_URL", "").start_with?("http://") ||
    ENV.fetch("MEMBER_OIDC_ISSUER_URL", "").start_with?("http://"))
  OpenIDConnect::ResponseObject::IdToken.class_eval do
    alias_method :original_verify!, :verify!

    def verify!(expected = {})
      original_verify!(expected)
    rescue OpenIDConnect::ResponseObject::IdToken::InvalidIssuer => e
      Rails.logger.warn "[OIDC] Skipping issuer verification in dev: #{e.message}"
    end
  end
end
