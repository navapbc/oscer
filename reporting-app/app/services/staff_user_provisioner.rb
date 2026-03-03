# frozen_string_literal: true

# Provisions staff user accounts from SSO identity provider claims
#
# Creates or updates staff users based on claims extracted from OIDC ID tokens.
# Uses RoleMapper to determine the appropriate OSCER role from IdP group memberships.
#
# Usage:
#   provisioner = StaffUserProvisioner.new
#   user = provisioner.provision!(claims)
#
# Claims format:
#   {
#     uid: "unique-id-from-idp",
#     email: "user@example.gov",
#     name: "Jane Doe",
#     groups: ["OSCER-Admin", "Other-Group"],
#     region: "Northeast"
#   }
#
# Behavior:
#   - Finds existing users by UID (not email) to handle email changes
#   - Updates attributes (name, email) on every login
#   - Assigns role based on group membership via RoleMapper
#   - Raises Auth::Errors::AccessDenied if no matching role and deny mode is enabled
#
class StaffUserProvisioner
  SSO_PROVIDER = "sso"

  # @param role_mapper [RoleMapper] Role mapper instance (injectable for testing)
  def initialize(role_mapper: RoleMapper.instance)
    @role_mapper = role_mapper
  end

  # Provision a staff user from IdP claims
  #
  # @param claims [Hash] Claims extracted from OIDC ID token
  # @option claims [String] :uid Unique identifier from IdP (required)
  # @option claims [String] :email User's email address (required)
  # @option claims [String] :name User's full name
  # @option claims [Array<String>] :groups IdP group memberships
  # @option claims [String] :region User's region (from custom:region attribute)
  # @return [User] The provisioned user record
  # @raise [Auth::Errors::AccessDenied] If no matching role and deny mode is enabled
  # @raise [ActiveRecord::RecordInvalid] If user validation fails
  def provision!(claims)
    validate_claims!(claims)

    user = find_or_initialize_user(claims[:uid], claims[:email])
    sync_attributes(user, claims)
    assign_role(user, claims[:groups])
    user.save!
    user
  end

  private

  def validate_claims!(claims)
    raise ArgumentError, "claims cannot be nil" if claims.nil?
    raise ArgumentError, "uid is required" if claims[:uid].blank?
    raise ArgumentError, "email is required" if claims[:email].blank?
  end

  def find_or_initialize_user(uid, email)
    # Find by UID to handle email changes correctly
    User.find_by(uid: uid) || User.new(uid: uid, email: email, provider: SSO_PROVIDER)
  end

  def sync_attributes(user, claims)
    user.email = claims[:email]
    user.full_name = claims[:name]
    user.region = claims[:region] if claims[:region].present?

    # SSO users don't need OSCER MFA - they authenticate through the IdP
    # which may have its own MFA requirements
    user.mfa_preference ||= "opt_out"
  end

  def assign_role(user, groups)
    role = @role_mapper.map_groups_to_role(groups)

    if role.nil? && @role_mapper.deny_if_no_match?
      raise Auth::Errors::AccessDenied
    end

    user.role = role || @role_mapper.default_role
  end
end
