# frozen_string_literal: true

require_relative "config_loading"

# Loads the verification Data Source registry by deep-merging an optional
# deployment override (config/custom/verification_data_sources.yml, the
# deployment-owned override surface) over the OSCER-owned DEFAULTS below.
#
# A "data source" is an external verification adapter (a Verification::DataSource
# subclass). Config owns enablement, wiring, and call order; the adapter class
# owns which outcome symbols it may emit via {.declared_outcomes}. Boot
# validation confirms those outcomes are known Determination::REASON_CODE_MAPPING
# keys (the "emit the key" convention).
#
# Call order among verification sources is configured here via the per-source
# order integer. Exception and community-engagement sources may interleave in
# the same business process, so there is one source call order rather than
# separate category-specific orders. Set order only for sources used in that
# shared exception/CE call sequence — leave it null for exclusion-only sources.
# Exclusion outcome ranking is NOT configured here: Exclusion.priority_order
# (config/custom/exclusion_types.yml) owns it.
#
# Validation is split in two so the initializer body stays boot-safe:
#
#   * .transform performs pure structural validation (shapes, required keys,
#     order types + distinctness) and needs no application constants, so it runs
#     in the initializer body and is unit-testable in isolation.
#   * .validate_registry! constantizes adapter_class, requires .declared_outcomes,
#     and checks each outcome against Determination::REASON_CODE_MAPPING keys.
#     That requires autoloadable app constants, so the initializer defers it to a
#     to_prepare hook.
#
# Mirrors ExclusionTypesLoader / ExemptionTypesLoader; the YAML load/parse/error
# plumbing lives in the shared ConfigLoading module (extend below).
module VerificationDataSourcesLoader
  extend ConfigLoading

  # Alias keeps VerificationDataSourcesLoader::ConfigurationError valid for
  # rescues/specs; unqualified `raise ConfigurationError` resolves to it via
  # lexical scope, so no raise site needs qualifying.
  ConfigurationError = ConfigLoading::ConfigurationError

  # OSCER-owned defaults. Empty: OSCER ships no default sources, so deployments
  # register their own via the override file rather than editing this constant.
  DEFAULTS = {}.freeze

  module_function

  def merge_with_defaults(overrides)
    DEFAULTS.deep_merge(overrides)
  end

  # Pure structural validation + normalization. Returns an Array of entries with
  # symbolized ids and a String adapter_class (constantized later, in
  # validate_registry!). Raises ConfigurationError naming the offending entry.
  def transform(merged)
    entries = merged.map { |id, attrs| transform_entry(id, attrs) }
    validate_order_distinctness!(entries)
    entries
  end

  # Application-constant-dependent validation. Must run after autoloading is
  # ready, so the initializer calls this from a to_prepare hook rather than the
  # body.
  def validate_registry!(entries)
    # Snapshot the valid keys once per boot validation pass.
    valid_outcomes = Determination::REASON_CODE_MAPPING.keys

    entries.each do |entry|
      klass = validate_adapter_class!(entry)
      outcomes = fetch_declared_outcomes!(entry, klass)
      validate_outcome_ids!(entry, outcomes, valid_outcomes)
    end
  end

  # ---- structural (boot-body-safe) ------------------------------------------

  def transform_entry(id, attrs)
    unless attrs.is_a?(Hash)
      raise ConfigurationError, "verification_data_sources.#{id}: expected Hash, got #{attrs.class}"
    end

    {
      id: id.to_sym,
      enabled: fetch_enabled(id, attrs),
      adapter_class: fetch_adapter_class(id, attrs),
      order: transform_order(id, "order", attrs)
    }
  end

  def fetch_enabled(id, attrs)
    unless attrs.key?("enabled")
      raise ConfigurationError, "verification_data_sources.#{id}: missing required 'enabled' field"
    end
    enabled = attrs["enabled"]
    unless [ true, false ].include?(enabled)
      raise ConfigurationError, "verification_data_sources.#{id}: 'enabled' must be true or false, got #{enabled.inspect}"
    end
    enabled
  end

  def fetch_adapter_class(id, attrs)
    adapter_class = attrs["adapter_class"]
    unless adapter_class.is_a?(String) && adapter_class.present?
      raise ConfigurationError, "verification_data_sources.#{id}: missing required 'adapter_class' (String)"
    end
    adapter_class
  end

  def transform_order(id, field, attrs)
    return nil unless attrs.key?(field)
    value = attrs[field]
    return nil if value.nil?
    unless value.is_a?(Integer)
      raise ConfigurationError, "verification_data_sources.#{id}: '#{field}' must be an Integer or null, got #{value.class}"
    end
    value
  end

  # A shared order value would make call order among sources depend on an unstable
  # sort, so reject duplicates at boot (mirrors ExclusionTypesLoader's priority guard).
  def validate_order_distinctness!(entries)
    values = entries.map { |entry| entry[:order] }.compact
    duplicates = values.tally.select { |_value, count| count > 1 }.keys.sort
    return if duplicates.empty?

    raise ConfigurationError,
      "verification_data_sources: duplicate order values #{duplicates}; each source's order must be distinct"
  end

  # ---- registry-dependent (to_prepare) --------------------------------------

  def validate_adapter_class!(entry)
    klass = entry[:adapter_class].safe_constantize
    if klass.nil?
      raise ConfigurationError,
        "verification_data_sources.#{entry[:id]}: adapter_class '#{entry[:adapter_class]}' does not constantize"
    end
    unless klass.is_a?(Class) && klass < Verification::DataSource
      raise ConfigurationError,
        "verification_data_sources.#{entry[:id]}: adapter_class '#{entry[:adapter_class]}' must be a Verification::DataSource subclass"
    end
    klass
  end

  def fetch_declared_outcomes!(entry, klass)
    declared = begin
      klass.declared_outcomes
    rescue NotImplementedError
      raise ConfigurationError,
        "verification_data_sources.#{entry[:id]}: adapter_class '#{entry[:adapter_class]}' must implement .declared_outcomes"
    end
    unless declared.is_a?(Array) && declared.all? { |outcome| outcome.is_a?(Symbol) }
      raise ConfigurationError,
        "verification_data_sources.#{entry[:id]}: '#{entry[:adapter_class]}.declared_outcomes' must return Array<Symbol>"
    end
    if entry[:enabled] && declared.empty?
      raise ConfigurationError,
        "verification_data_sources.#{entry[:id]}: enabled source must declare at least one outcome via .declared_outcomes"
    end
    declared
  end

  # Every declared outcome must be a known Determination reason-code key;
  # unknown keys raise so typos fail loudly at boot.
  def validate_outcome_ids!(entry, outcomes, valid_outcomes)
    unknown = outcomes - valid_outcomes
    return if unknown.empty?

    raise ConfigurationError,
      "verification_data_sources.#{entry[:id]}: .declared_outcomes references unknown id(s) #{unknown.map(&:to_s)}; " \
      "valid ids are Determination::REASON_CODE_MAPPING keys (#{valid_outcomes.map(&:to_s).sort})"
  end
end
