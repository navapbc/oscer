# frozen_string_literal: true

# Provisions member user accounts from citizen IdP OIDC claims
#
# Creates or updates member users based on claims extracted from OIDC ID tokens.
# Unlike StaffUserProvisioner, this does not use RoleMapper since members do not
# have staff roles.
#
# Usage:
#   provisioner = MemberOidcProvisioner.new
#   user = provisioner.provision!(claims)
#
# Claims format:
#   {
#     uid: "unique-id-from-idp",
#     email: "member@example.com",
#     name: "John Smith"
#   }
#
# Behavior:
#   - Finds existing users by UID (not email) to handle email changes
#   - Updates attributes (name, email) on every login
#   - Does NOT set or change role (members have no staff role)
#   - Sets mfa_preference to "opt_out" since IdP handles MFA
#
class MemberOidcProvisioner
  PROVIDER = "member_oidc"

  # Provision a member user from IdP claims
  #
  # @param claims [Hash] Claims extracted from OIDC ID token
  # @option claims [String] :uid Unique identifier from IdP (required)
  # @option claims [String] :email User's email address (required)
  # @option claims [String] :name User's full name
  # @return [User] The provisioned user record
  # @raise [ArgumentError] If required claims (uid, email) are missing
  # @raise [ActiveRecord::RecordInvalid] If user validation fails
  def provision!(claims)
    validate_claims!(claims)

    user = find_or_initialize_user(claims[:uid], claims[:email])
    sync_attributes(user, claims)
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
    User.find_by(uid: uid) || User.new(uid: uid, email: email, provider: PROVIDER)
  end

  def sync_attributes(user, claims)
    user.email = claims[:email]
    user.full_name = claims[:name]
    user.provider = PROVIDER

    # IdP handles MFA; skip app MFA preference/challenge (same as StaffUserProvisioner)
    user.mfa_preference ||= "opt_out"
  end
end
