# frozen_string_literal: true

require_relative "config_loading"

# Loads external-exception configuration by deep-merging an optional deployment
# override (config/custom/external_exceptions.yml, the deployment-owned override
# surface) over the federal-floor defaults declared in DEFAULTS below.
#
# These are the optional short-term hardship exceptions the external exception
# check evaluates (see ExceptionDeterminationService). "Exception" is distinct
# from "exclusion" and "exemption" — do not conflate the three.
#
# Defaults represent OSCER's federal floor and are OSCER-owned (updated by
# Nava as CMS regulations evolve). Deployments customize via the override
# file, not by editing this constant.
#
# The YAML load/parse/error plumbing lives in the shared ConfigLoading module
# (extend below); this loader keeps only its deep-merge + transform logic. It
# mirrors ExemptionTypesLoader intentionally.
module ExternalExceptionsLoader
  extend ConfigLoading

  # Alias keeps ExternalExceptionsLoader::ConfigurationError valid for
  # rescues/specs; unqualified `raise ConfigurationError` in transform resolves
  # to it via lexical scope, so no raise site changes.
  ConfigurationError = ConfigLoading::ConfigurationError

  DEFAULTS = {
    "inpatient_medical_care" => { "enabled" => true },
    "declared_emergency_county" => { "enabled" => true },
    "high_unemployment_county" => { "enabled" => true },
    "medical_travel" => { "enabled" => true }
  }.freeze

  module_function

  def merge_with_defaults(overrides)
    DEFAULTS.deep_merge(overrides)
  end

  def transform(merged)
    merged.map do |id, attrs|
      unless attrs.is_a?(Hash)
        raise ConfigurationError, "external_exceptions.#{id}: expected Hash, got #{attrs.class}"
      end
      unless attrs.key?("enabled")
        raise ConfigurationError, "external_exceptions.#{id}: missing required 'enabled' field"
      end
      attrs.symbolize_keys.merge(id: id.to_sym)
    end
  end
end
