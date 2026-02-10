# frozen_string_literal: true

# Shared test helpers for SSO/OIDC testing
# Used by OidcClient, StaffUserProvisioner, RoleMapper, and controller specs
module SsoHelpers
  # Returns mock staff user claims for provisioning tests
  # @param overrides [Hash] values to override in the default claims
  # @return [Hash] Staff claims with symbol keys
  def mock_staff_claims(overrides = {})
    {
      uid: "staff-user-123",
      email: "jane.doe@example.gov",
      name: "Jane Doe",
      groups: [ "OSCER-Caseworker" ]
    }.merge(overrides)
  end

  # Returns a mock role mapping configuration hash
  # @param overrides [Hash] values to override in the default config
  # @return [Hash] Role mapping configuration
  def mock_role_mapping_config(overrides = {})
    {
      role_mappings: {
        admin: [ "OSCER-Admin", "CE-Administrators" ],
        caseworker: [ "OSCER-Caseworker", "OSCER-Staff", "CE-Staff" ]
      },
      no_match_behavior: "deny",
      default_role: nil
    }.deep_merge(overrides)
  end

  # Returns a mock SSO configuration hash
  # @param overrides [Hash] values to override in the default config
  # @return [Hash] SSO configuration
  def mock_oidc_config(overrides = {})
    {
      enabled: true,
      issuer: "https://test-idp.example.com",
      discovery_url: "https://test-idp.example.com",
      client_id: "test-client-id",
      client_secret: "test-client-secret",
      redirect_uri: "http://localhost:3000/auth/sso/callback",
      scopes: %w[openid profile email groups],
      claims: {
        email: "email",
        name: "name",
        groups: "groups",
        unique_id: "sub"
      }
    }.deep_merge(overrides)
  end

  # Returns mock ID token claims
  # @param overrides [Hash] values to override in the default claims
  # @return [Hash] JWT claims
  def mock_id_token_claims(overrides = {})
    {
      "sub" => "user-123",
      "email" => "staff@example.gov",
      "name" => "Jane Doe",
      "groups" => [ "OSCER-Caseworker" ],
      "iss" => "https://test-idp.example.com",
      "aud" => "test-client-id",
      "exp" => 1.hour.from_now.to_i,
      "iat" => Time.current.to_i,
      "nonce" => "test-nonce"
    }.merge(overrides)
  end

  # Creates a valid JWT token from claims (unsigned, for testing)
  # @param claims [Hash] JWT claims
  # @return [String] JWT token string
  def create_test_jwt(claims)
    header = { alg: "RS256", typ: "JWT" }
    payload = claims

    # Create unsigned JWT for testing (signature verification is mocked)
    [
      Base64.urlsafe_encode64(header.to_json, padding: false),
      Base64.urlsafe_encode64(payload.to_json, padding: false),
      "test-signature"
    ].join(".")
  end

  # Stubs the Faraday HTTP response for token exchange
  # @param claims [Hash] claims to include in the ID token
  # @param access_token [String] optional access token
  def stub_oidc_token_exchange(claims:, access_token: "test-access-token")
    id_token = create_test_jwt(claims)

    response_body = {
      "access_token" => access_token,
      "id_token" => id_token,
      "token_type" => "Bearer",
      "expires_in" => 3600
    }.to_json

    stub_request(:post, "https://test-idp.example.com/token")
      .to_return(
        status: 200,
        body: response_body,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stubs a failed token exchange
  # @param error [String] error code
  # @param description [String] error description
  def stub_oidc_token_exchange_failure(error: "invalid_grant", description: "Invalid authorization code")
    response_body = {
      "error" => error,
      "error_description" => description
    }.to_json

    stub_request(:post, "https://test-idp.example.com/token")
      .to_return(
        status: 400,
        body: response_body,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stubs the OIDC discovery endpoint (JWKS)
  # @param issuer [String] the IdP issuer URL
  def stub_oidc_discovery(issuer: "https://test-idp.example.com")
    # OpenID Configuration
    openid_config = {
      "issuer" => issuer,
      "authorization_endpoint" => "#{issuer}/authorize",
      "token_endpoint" => "#{issuer}/token",
      "jwks_uri" => "#{issuer}/.well-known/jwks.json",
      "userinfo_endpoint" => "#{issuer}/userinfo"
    }.to_json

    stub_request(:get, "#{issuer}/.well-known/openid-configuration")
      .to_return(
        status: 200,
        body: openid_config,
        headers: { "Content-Type" => "application/json" }
      )

    # JWKS (empty for now - we'll mock JWT validation)
    jwks = { "keys" => [] }.to_json

    stub_request(:get, "#{issuer}/.well-known/jwks.json")
      .to_return(
        status: 200,
        body: jwks,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Sets up SSO config in Rails for testing
  # @param config [Hash] SSO configuration (uses mock_oidc_config by default)
  def configure_sso_for_test(config = nil)
    config ||= mock_oidc_config
    allow(Rails.application.config).to receive(:sso).and_return(config)
  end
end

RSpec.configure do |config|
  config.include SsoHelpers, type: :service
  config.include SsoHelpers, type: :request
  config.include SsoHelpers, sso: true
end
