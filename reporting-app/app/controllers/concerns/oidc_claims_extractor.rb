# frozen_string_literal: true

# Shared OIDC behavior for staff SSO and member OIDC controllers.
# - Claim extraction from OmniAuth auth hash (config.sso[:claims] / config.member_oidc[:claims])
# - Redirect if already authenticated (before_action)
# - Sanitized OmniAuth failure message for logging (avoid log injection)
#
module OidcClaimsExtractor
  extend ActiveSupport::Concern

  ALLOWED_OMNIAUTH_FAILURE_MESSAGES = %w[invalid_credentials timeout].freeze

  # Extract claims from OmniAuth auth hash using the given claim configuration.
  #
  # @param auth [OmniAuth::AuthHash] The auth hash from request.env["omniauth.auth"]
  # @param claim_config [Hash] Config with symbol keys (:email, :name, :unique_id, optional :groups, :region)
  # @return [Hash] Symbol-keyed hash with :uid, :email, :name, and optionally :groups, :region
  def extract_oidc_claims(auth, claim_config)
    raw = (auth.extra&.raw_info || {}).with_indifferent_access

    uid_key = claim_config[:unique_id]
    uid = uid_key.present? ? raw[uid_key] : auth.uid
    uid = auth.uid if uid.blank?

    claims = {
      uid: uid.to_s,
      email: raw[claim_config[:email]],
      name: raw[claim_config[:name]]
    }

    claims[:groups] = Array(raw[claim_config[:groups]]) if claim_config.key?(:groups)
    claims[:region] = raw[claim_config[:region]] if claim_config.key?(:region)

    claims
  end

  # Redirect to after_sign_in_path if user is already signed in. Use as before_action on :new.
  def redirect_if_authenticated
    return unless user_signed_in?

    redirect_to after_sign_in_path_for(current_user)
  end

  # Return allowlisted OmniAuth failure message to avoid log injection. Used in failure action.
  # @param raw [String, nil] Raw message from params[:message]
  # @return [String] "invalid_credentials", "timeout", or "unknown_error"
  def sanitized_failure_message(raw)
    return "unknown_error" if raw.blank?

    msg = raw.to_s.strip
    ALLOWED_OMNIAUTH_FAILURE_MESSAGES.include?(msg) ? msg : "unknown_error"
  end
end
