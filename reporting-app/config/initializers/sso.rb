# frozen_string_literal: true

# Build redirect URI with correct scheme and port
# Defaults to HTTPS (production assumption) unless explicitly disabled
# Set ENABLE_HTTPS=false for local development without SSL
def build_sso_redirect_uri
  host = ENV.fetch("APP_HOST", "localhost")
  port = ENV.fetch("APP_PORT", "443")
  https_enabled = ENV.fetch("ENABLE_HTTPS", "true") == "true"

  scheme = https_enabled ? "https" : "http"
  standard_port = https_enabled ? "443" : "80"
  port_suffix = (port == standard_port) ? "" : ":#{port}"

  "#{scheme}://#{host}#{port_suffix}/auth/sso/callback"
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
if Rails.application.config.sso[:enabled] || Rails.env.test?
  issuer_url = ENV.fetch("SSO_ISSUER_URL", "https://test-idp.example.com")
  issuer_uri = URI.parse(issuer_url)
  use_http = issuer_url.start_with?("http://")

  # For Docker: SSO_INTERNAL_HOST allows Rails to reach IdP via container name
  # while browser uses localhost
  internal_host = ENV.fetch("SSO_INTERNAL_HOST") { issuer_uri.host }
  internal_base = "#{issuer_uri.scheme}://#{internal_host}:#{issuer_uri.port}#{issuer_uri.path}"

  Rails.application.config.middleware.use OmniAuth::Builder do
    provider_options = {
      name: :sso,
      issuer: issuer_url,
      scope: ENV.fetch("SSO_SCOPES", "openid profile email").split,
      response_type: :code,
      discovery: !use_http, # Use discovery for HTTPS, manual for HTTP
      client_options: {
        identifier: ENV.fetch("SSO_CLIENT_ID", "test-client"),
        secret: ENV.fetch("SSO_CLIENT_SECRET", "test-secret"),
        redirect_uri: build_sso_redirect_uri
      }
    }

    # For HTTP (local Keycloak): manually specify endpoints since discovery won't work
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

# OmniAuth configuration
OmniAuth.config.logger = Rails.logger
# Only allow POST for security (CVE-2015-9284)
# The /sso/login page auto-submits a form via POST with Rails CSRF token
OmniAuth.config.allowed_request_methods = [ :post ]
# The omniauth-rails_csrf_protection gem validates Rails CSRF token via before_request_phase
# Disable OmniAuth's built-in Rack-based CSRF check (which uses different token format)
OmniAuth.config.request_validation_phase = nil

# WORKAROUND: Skip issuer verification for local HTTP development
# The openid_connect gem doesn't properly pass issuer when discovery is disabled
# This only applies to HTTP URLs (local dev), HTTPS production works normally
if Rails.env.development? && ENV.fetch("SSO_ISSUER_URL", "").start_with?("http://")
  OpenIDConnect::ResponseObject::IdToken.class_eval do
    alias_method :original_verify!, :verify!

    def verify!(expected = {})
      original_verify!(expected)
    rescue OpenIDConnect::ResponseObject::IdToken::InvalidIssuer => e
      Rails.logger.warn "[SSO] Skipping issuer verification in dev: #{e.message}"
    end
  end
end
