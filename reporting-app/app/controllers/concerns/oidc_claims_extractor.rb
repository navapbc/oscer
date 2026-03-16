# frozen_string_literal: true

# Extracts OIDC claims from an OmniAuth auth hash using a configurable claim mapping.
# Used by both staff SSO (config.sso[:claims]) and member OIDC (config.member_oidc[:claims]).
#
# Claim config is a hash of symbol keys to IdP claim names, e.g.:
#   { email: "email", name: "name", unique_id: "sub", groups: "groups", region: "custom:region" }
# Member config typically has only email, name, unique_id.
#
module OidcClaimsExtractor
  extend ActiveSupport::Concern

  # Extract claims from OmniAuth auth hash using the given claim configuration.
  #
  # @param auth [OmniAuth::AuthHash] The auth hash from request.env["omniauth.auth"]
  # @param claim_config [Hash] Config with symbol keys (:email, :name, :unique_id, optional :groups, :region)
  # @return [Hash] Symbol-keyed hash with :uid, :email, :name, and optionally :groups, :region
  def extract_oidc_claims(auth, claim_config)
    raw_info = auth.extra&.raw_info || {}
    # Support both string and symbol keys (OmniAuth::AuthHash can use either)
    raw = raw_info.respond_to?(:with_indifferent_access) ? raw_info.with_indifferent_access : raw_info

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
end
