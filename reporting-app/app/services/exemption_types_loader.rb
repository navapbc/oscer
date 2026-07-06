# frozen_string_literal: true

require_relative "config_loading"

# Loads exemption-type configuration by deep-merging an optional deployment
# override (config/custom/exemption_types.yml, the deployment-owned override
# surface) over the federal-floor defaults declared in DEFAULTS below.
#
# Defaults represent OSCER's federal floor and are OSCER-owned (updated by
# Nava as CMS regulations evolve). Deployments customize via the override
# file, not by editing this constant.
#
# The YAML load/parse/error plumbing lives in the shared ConfigLoading module
# (extend below); this loader keeps only its deep-merge + transform logic.
module ExemptionTypesLoader
  extend ConfigLoading

  # Alias keeps ExemptionTypesLoader::ConfigurationError valid for existing
  # rescues/specs; unqualified `raise ConfigurationError` in transform resolves
  # to it via lexical scope, so no raise site changes.
  ConfigurationError = ConfigLoading::ConfigurationError

  DEFAULTS = {
    "caregiver_disability" => { "enabled" => true },
    "caregiver_child" => { "enabled" => true },
    "medical_condition" => { "enabled" => true },
    "substance_treatment" => { "enabled" => true },
    "incarceration" => { "enabled" => true },
    "education_and_training" => { "enabled" => true },
    "received_medical_care" => { "enabled" => true }
  }.freeze

  module_function

  def merge_with_defaults(overrides)
    DEFAULTS.deep_merge(overrides)
  end

  def transform(merged)
    merged.map do |id, attrs|
      unless attrs.is_a?(Hash)
        raise ConfigurationError, "exemption_types.#{id}: expected Hash, got #{attrs.class}"
      end
      unless attrs.key?("enabled")
        raise ConfigurationError, "exemption_types.#{id}: missing required 'enabled' field"
      end
      attrs.symbolize_keys.merge(id: id.to_sym)
    end
  end
end
