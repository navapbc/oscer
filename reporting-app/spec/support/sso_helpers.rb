# frozen_string_literal: true

# Shared test helpers for SSO and OIDC testing
# Used by StaffUserProvisioner, MemberOidcProvisioner, RoleMapper, and controller specs
module SsoHelpers
  # Returns mock staff user claims for provisioning tests
  # @param overrides [Hash] values to override in the default claims
  # @return [Hash] Staff claims with symbol keys
  def mock_staff_claims(overrides = {})
    {
      uid: "staff-user-123",
      email: "jane.doe@example.gov",
      name: "Jane Doe",
      groups: [ "OSCER-Caseworker" ],
      region: nil
    }.merge(overrides)
  end

  # Returns mock member user claims for provisioning tests
  # @param overrides [Hash] values to override in the default claims
  # @return [Hash] Member claims with symbol keys (no groups or region)
  def mock_member_claims(overrides = {})
    {
      uid: "member-user-456",
      email: "john.smith@example.com",
      name: "John Smith"
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

  # Returns a mock SSO configuration hash for Rails.application.config.sso
  # @param overrides [Hash] values to override in the default config
  # @return [Hash] SSO configuration
  def mock_sso_config(overrides = {})
    {
      enabled: true,
      claims: {
        email: "email",
        name: "name",
        groups: "groups",
        unique_id: "sub",
        region: "custom:region"
      }
    }.deep_merge(overrides)
  end

  # Creates a mock OmniAuth auth hash for staff SSO testing callbacks
  # @param overrides [Hash] values to override in the default auth hash
  # @return [OmniAuth::AuthHash] Mock auth hash
  def mock_omniauth_hash(overrides = {})
    defaults = {
      provider: "sso",
      uid: "user-123",
      info: {
        email: "staff@example.gov",
        name: "Jane Doe"
      },
      extra: {
        raw_info: {
          "sub" => "user-123",
          "email" => "staff@example.gov",
          "name" => "Jane Doe",
          "groups" => [ "OSCER-Caseworker" ],
          "custom:region" => nil
        }
      }
    }

    OmniAuth::AuthHash.new(defaults.deep_merge(overrides))
  end

  # Creates a mock OmniAuth auth hash for member OIDC testing callbacks
  # @param overrides [Hash] values to override in the default auth hash
  # @return [OmniAuth::AuthHash] Mock auth hash for member OIDC
  def mock_member_omniauth_hash(overrides = {})
    defaults = {
      provider: "member_oidc",
      uid: "member-user-456",
      info: {
        email: "member@example.com",
        name: "John Smith"
      },
      extra: {
        raw_info: {
          "sub" => "member-user-456",
          "email" => "member@example.com",
          "name" => "John Smith"
        }
      }
    }

    OmniAuth::AuthHash.new(defaults.deep_merge(overrides))
  end

  # Sets up OmniAuth test mode with a mock auth hash for staff SSO
  # @param auth_hash [OmniAuth::AuthHash] Auth hash to return (uses mock_omniauth_hash by default)
  def setup_omniauth_mock(auth_hash = nil)
    auth_hash ||= mock_omniauth_hash
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:sso] = auth_hash
  end

  # Sets up OmniAuth test mode with a mock auth hash for member OIDC
  # @param auth_hash [OmniAuth::AuthHash] Auth hash to return (uses mock_member_omniauth_hash by default)
  def setup_member_omniauth_mock(auth_hash = nil)
    auth_hash ||= mock_member_omniauth_hash
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:member_oidc] = auth_hash
  end

  # Sets up OmniAuth to return a failure for staff SSO
  # @param message [Symbol] Failure message/type
  def setup_omniauth_failure(message = :invalid_credentials)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:sso] = message
  end

  # Sets up OmniAuth to return a failure for member OIDC
  # @param message [Symbol] Failure message/type
  def setup_member_omniauth_failure(message = :invalid_credentials)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:member_oidc] = message
  end

  # Resets OmniAuth test mode for staff SSO
  def reset_omniauth
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:sso] = nil
  end

  # Resets OmniAuth test mode for member OIDC
  def reset_member_omniauth
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:member_oidc] = nil
  end

  # Resets OmniAuth test mode for all providers
  def reset_all_omniauth
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:sso] = nil
    OmniAuth.config.mock_auth[:member_oidc] = nil
  end

  # Sets up SSO config in Rails for testing
  # @param config [Hash] SSO configuration (uses mock_sso_config by default)
  def configure_sso_for_test(config = nil)
    config ||= mock_sso_config
    allow(Rails.application.config).to receive(:sso).and_return(config)
  end

  # Returns a mock member OIDC configuration hash for Rails.application.config.member_oidc
  # @param overrides [Hash] values to override in the default config
  # @return [Hash] Member OIDC configuration
  def mock_member_oidc_config(overrides = {})
    {
      enabled: true,
      claims: {
        email: "email",
        name: "name",
        unique_id: "sub"
      }
    }.deep_merge(overrides)
  end

  # Sets up member OIDC config in Rails for testing
  # @param config [Hash] Member OIDC configuration (uses mock_member_oidc_config by default)
  def configure_member_oidc_for_test(config = nil)
    config ||= mock_member_oidc_config
    allow(Rails.application.config).to receive(:member_oidc).and_return(config)
  end
end

RSpec.configure do |config|
  config.include SsoHelpers, type: :service
  config.include SsoHelpers, type: :request
  config.include SsoHelpers, type: :helper
  config.include SsoHelpers, sso: true

  # Reset OmniAuth after each SSO/OIDC test
  config.after(:each, type: :request) do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:sso] = nil
    OmniAuth.config.mock_auth[:member_oidc] = nil
  end
end
