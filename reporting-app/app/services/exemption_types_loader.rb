# frozen_string_literal: true

# Loads exemption-type configuration by deep-merging an optional deployment
# override (config/custom/exemption_types.yml — preserved across
# `nava-platform app update` via Copier's _skip_if_exists directive for
# zero-conflict updates) over the federal-floor defaults declared in
# DEFAULTS below.
#
# Defaults represent OSCER's federal floor and are template-owned (updated
# by Nava as CMS regulations evolve). Deployments customize via the
# override file, not by editing this constant.
module ExemptionTypesLoader
  class ConfigurationError < StandardError; end

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

  def safe_load_optional(path)
    return {} unless File.exist?(path)
    parse_yaml(path)
  end

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

  def parse_yaml(path)
    raw = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
    return {} if raw.nil?
    unless raw.is_a?(Hash)
      raise ConfigurationError, "Expected a Hash at top level in #{path}, got #{raw.class}"
    end
    raw
  rescue Psych::SyntaxError, Psych::DisallowedClass => e
    raise ConfigurationError, "Invalid YAML in #{path}: #{e.message}"
  end
end
