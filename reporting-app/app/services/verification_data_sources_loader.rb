# frozen_string_literal: true

require_relative "config_loading"

# Loads the verification Data Source registry by deep-merging an optional
# deployment override (config/custom/verification_data_sources.yml, the
# deployment-owned override surface) over the OSCER-owned DEFAULTS below.
#
# A "data source" is an external verification adapter (a Verification::DataSource
# subclass) plus a declaration of which checks it can make, grouped by category:
#
#   * exclusion  — ids must be a subset of Exclusion.valid_values
#   * exception  — ids must be a subset of the ExternalException registry
#   * ce         — community-engagement ids; no registry exists yet, so these are
#                  structurally validated but not membership-checked (see below)
#
# Call order among *exception* and *CE* sources is configured here via the
# per-source exception_order / ce_order integers. Exclusion call/selection order
# is NOT configured here: Exclusion.priority_order (config/custom/exclusion_types.yml)
# owns it, so an exclusion_order key on an entry is rejected at boot.
#
# Validation is split in two so the initializer body stays boot-safe:
#
#   * .transform performs pure structural validation (shapes, required keys,
#     order types + distinctness) and needs no application constants, so it runs
#     in the initializer body and is unit-testable in isolation.
#   * .validate_registry! constantizes adapter_class and checks category ids
#     against their registries. Both require autoloadable app constants (and the
#     sibling exclusion/exception initializers to have run), so the initializer
#     defers it to a to_prepare hook.
#
# Mirrors ExclusionTypesLoader / ExemptionTypesLoader; the YAML load/parse/error
# plumbing lives in the shared ConfigLoading module (extend below).
module VerificationDataSourcesLoader
  extend ConfigLoading

  # Alias keeps VerificationDataSourcesLoader::ConfigurationError valid for
  # rescues/specs; unqualified `raise ConfigurationError` resolves to it via
  # lexical scope, so no raise site needs qualifying.
  ConfigurationError = ConfigLoading::ConfigurationError

  # Check categories a source may declare under `checks`. Exclusion and exception
  # each have a backing registry; :ce does not yet (its ids are shape-checked but
  # not membership-checked until a CE registry lands).
  CATEGORIES = %i[exclusion exception ce].freeze

  # OSCER-owned defaults. Deployments customize via the override file, not by
  # editing this constant. The VA disability-rating source lands here as the
  # first real registered source (OSCER-755 adapter, OSCER-756 registry).
  DEFAULTS = {
    "va_disability_rating" => {
      "enabled" => true,
      "adapter_class" => "Verification::Adapters::VaDisabilityRating",
      "checks" => {
        "exclusion" => [ "is_veteran_with_disability" ],
        "exception" => [],
        "ce" => []
      },
      "exception_order" => nil,
      "ce_order" => nil
    }
  }.freeze

  module_function

  def merge_with_defaults(overrides)
    DEFAULTS.deep_merge(overrides)
  end

  # Pure structural validation + normalization. Returns an Array of entries with
  # symbolized ids/categories and a String adapter_class (constantized later, in
  # validate_registry!). Raises ConfigurationError naming the offending entry.
  def transform(merged)
    entries = merged.map { |id, attrs| transform_entry(id, attrs) }
    validate_order_distinctness!(entries)
    entries
  end

  # Application-constant-dependent validation. Must run after autoloading is
  # ready and after the sibling registries are populated, so the initializer
  # calls this from a to_prepare hook rather than the body.
  def validate_registry!(entries)
    entries.each do |entry|
      validate_adapter_class!(entry)
      validate_check_ids!(entry)
    end
  end

  # ---- structural (boot-body-safe) ------------------------------------------

  def transform_entry(id, attrs)
    unless attrs.is_a?(Hash)
      raise ConfigurationError, "verification_data_sources.#{id}: expected Hash, got #{attrs.class}"
    end
    reject_exclusion_order!(id, attrs)

    {
      id: id.to_sym,
      enabled: fetch_enabled(id, attrs),
      adapter_class: fetch_adapter_class(id, attrs),
      checks: transform_checks(id, attrs["checks"]),
      exception_order: transform_order(id, "exception_order", attrs),
      ce_order: transform_order(id, "ce_order", attrs)
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

  def transform_checks(id, checks)
    unless checks.is_a?(Hash)
      raise ConfigurationError, "verification_data_sources.#{id}: 'checks' must be a Hash keyed by category (#{CATEGORIES.join(', ')})"
    end

    unknown = checks.keys.map(&:to_sym) - CATEGORIES
    unless unknown.empty?
      raise ConfigurationError, "verification_data_sources.#{id}: unknown check category #{unknown.map(&:to_s)}; valid categories are #{CATEGORIES.map(&:to_s)}"
    end

    CATEGORIES.index_with { |category| normalize_check_ids(id, category, checks[category.to_s]) }
  end

  def normalize_check_ids(id, category, raw)
    return [] if raw.nil?
    unless raw.is_a?(Array)
      raise ConfigurationError, "verification_data_sources.#{id}: checks.#{category} must be an Array of ids, got #{raw.class}"
    end
    raw.map do |check_id|
      unless check_id.is_a?(String) && check_id.present?
        raise ConfigurationError, "verification_data_sources.#{id}: checks.#{category} contains a non-String id #{check_id.inspect}"
      end
      check_id.to_sym
    end
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

  # Exclusion call/selection order is owned by Exclusion.priority_order, not this
  # registry. Reject the key rather than silently ignore it, so a deployment that
  # sets it here gets a clear boot error pointing at the right knob.
  def reject_exclusion_order!(id, attrs)
    return unless attrs.key?("exclusion_order")
    raise ConfigurationError,
      "verification_data_sources.#{id}: 'exclusion_order' is not configurable here; " \
      "exclusion order is owned by Exclusion.priority_order (config/custom/exclusion_types.yml)"
  end

  # A shared order value would make call order among sources depend on an unstable
  # sort, so reject duplicates at boot (mirrors ExclusionTypesLoader's priority guard).
  def validate_order_distinctness!(entries)
    %i[exception_order ce_order].each do |field|
      values = entries.map { |e| e[field] }.compact
      duplicates = values.tally.select { |_value, count| count > 1 }.keys.sort
      next if duplicates.empty?
      raise ConfigurationError,
        "verification_data_sources: duplicate #{field} values #{duplicates}; each source's #{field} must be distinct"
    end
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
  end

  def validate_check_ids!(entry)
    entry[:checks].each do |category, ids|
      valid_ids = category_valid_ids(category)
      next if valid_ids.nil? # no registry for this category yet (e.g. :ce)

      unknown = ids.reject { |check_id| valid_ids.include?(check_id) }
      next if unknown.empty?
      raise ConfigurationError,
        "verification_data_sources.#{entry[:id]}: checks.#{category} references unknown id(s) #{unknown.map(&:to_s)}; " \
        "valid #{category} ids: #{valid_ids.map(&:to_s).sort}"
    end
  end

  # Valid ids for a category as Symbols, or nil when no registry backs it yet.
  def category_valid_ids(category)
    case category
    when :exclusion then Exclusion.valid_values.map(&:to_sym)
    when :exception then ExternalException.all.map { |entry| entry[:id] }
    end
  end
end
