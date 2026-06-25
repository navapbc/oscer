# frozen_string_literal: true

# Builds the in-memory feature-flag registry by adding optional
# deployment-defined flags (config/custom/feature_flags.yml, the
# deployment-owned override surface) onto the OSCER-shipped built-ins declared
# in Features::FEATURE_FLAGS.
#
# OSCER-shipped built-ins are OSCER-owned (updated by Nava as features ship and
# stabilize). Deployments add their own deployment-specific flags via the
# override file. The override is ADDITIVE ONLY: a deployment cannot redefine or
# disable a built-in here. To toggle a built-in, set its env var.
#
# Mirrors ExemptionTypesLoader's load/validate discipline:
#   - safe_load_optional treats a missing/empty file as "no overrides"
#   - parse_yaml uses YAML.safe_load (no Ruby object deserialization)
#   - build_registry raises a ConfigurationError naming the offending entry and
#     field on any malformed/colliding deployment flag, so misconfiguration
#     fails loudly at boot rather than silently at runtime.
#
# Merge semantics intentionally DIFFER from ExemptionTypesLoader: that loader
# deep_merges deployment values over OSCER defaults (the deployment owns the
# data and may override it), whereas feature flags are OSCER-owned rollout
# state, so this loader is purely ADDITIVE and raises on any collision. Do not
# "align" the two by introducing deep_merge here.
module FeatureFlagsLoader
  class ConfigurationError < StandardError; end

  # Deployment-defined env vars must match the same FEATURE_<NAME> convention
  # the built-ins follow: "FEATURE_" + uppercase letters/digits/underscores.
  ENV_VAR_PATTERN = /\AFEATURE_[A-Z0-9_]+\z/

  # A deployment flag's name becomes the registry key and seeds the generated
  # Features.<name>_enabled? predicate (config/initializers/feature_flags.rb,
  # via define_method). define_method accepts any string, so a non-snake_case
  # name (e.g. kebab-case "my-flag") would silently define an uncallable
  # predicate rather than fail. Require snake_case so a bad name fails loudly at
  # boot, matching the convention the built-ins already follow.
  NAME_PATTERN = /\A[a-z][a-z0-9_]*\z/

  # The only keys a deployment-defined flag entry may declare. An entry with any
  # other key (e.g. a typo'd "descrption") fails loudly at boot rather than
  # silently carrying the stray key into the registry.
  ALLOWED_ENTRY_KEYS = %w[env_var default description].freeze

  module_function

  def safe_load_optional(path)
    return {} unless File.exist?(path)
    parse_yaml(path)
  end

  # Merge deployment overrides on top of the OSCER-shipped built-ins.
  #
  # @param built_ins [Hash{Symbol=>Hash}] frozen OSCER-shipped flags
  #   (Features::FEATURE_FLAGS) keyed by Symbol.
  # @param overrides [Hash{String=>Hash}] parsed deployment YAML, keyed by
  #   String flag name (from safe_load_optional).
  # @return [Hash{Symbol=>Hash}] merged registry keyed by Symbol, with each
  #   entry's attribute keys symbolized.
  # @raise [ConfigurationError] if any deployment entry is malformed or
  #   collides with a built-in.
  def build_registry(built_ins, overrides)
    registry = built_ins.dup

    # A flag's behavioral identity is its env var, not its name: two flags
    # pointing at the same env var toggle together. Track every claimed env var
    # (built-ins first) so a deployment entry can neither shadow a built-in's
    # env var under a different name nor collide with another deployment entry.
    claimed_env_vars = built_ins.each_value.map { |config| config[:env_var] }

    overrides.each do |name, attrs|
      # Validate the entry (incl. that the name is a snake_case String) before
      # name.to_sym, so a non-String YAML key fails with a named ConfigurationError
      # rather than a NoMethodError from to_sym.
      validate_entry!(name, attrs)

      flag = name.to_sym

      if built_ins.key?(flag)
        raise ConfigurationError,
              "feature_flags.#{name}: collides with an OSCER-shipped built-in. " \
              "Deployments cannot redefine or disable built-ins; toggle them via their env var instead."
      end

      env_var = attrs["env_var"]
      if claimed_env_vars.include?(env_var)
        raise ConfigurationError,
              "feature_flags.#{name}: 'env_var' #{env_var.inspect} is already in use by another flag. " \
              "Each flag needs a distinct env var; reusing a built-in's env var would shadow it."
      end
      claimed_env_vars << env_var

      registry[flag] = attrs.symbolize_keys
    end

    registry
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

  # Validate a single deployment-defined flag entry. Each entry requires an
  # `env_var` matching the FEATURE_<NAME> shape and a Boolean `default`.
  def validate_entry!(name, attrs)
    unless name.is_a?(String) && NAME_PATTERN.match?(name)
      raise ConfigurationError,
            "feature_flags.#{name}: flag name must be snake_case matching #{NAME_PATTERN.source} " \
            "(lowercase, starting with a letter), got #{name.inspect}"
    end

    unless attrs.is_a?(Hash)
      raise ConfigurationError, "feature_flags.#{name}: expected Hash, got #{attrs.class}"
    end

    unknown_keys = attrs.keys - ALLOWED_ENTRY_KEYS
    unless unknown_keys.empty?
      raise ConfigurationError,
            "feature_flags.#{name}: unknown key(s) #{unknown_keys.join(', ')}; " \
            "allowed keys are #{ALLOWED_ENTRY_KEYS.join(', ')}"
    end

    env_var = attrs["env_var"]
    unless env_var.is_a?(String) && ENV_VAR_PATTERN.match?(env_var)
      raise ConfigurationError,
            "feature_flags.#{name}: 'env_var' must match #{ENV_VAR_PATTERN.source} " \
            "(e.g. FEATURE_#{name.to_s.upcase}), got #{env_var.inspect}"
    end

    unless attrs.key?("default")
      raise ConfigurationError, "feature_flags.#{name}: missing required 'default' field"
    end

    default = attrs["default"]
    unless [ true, false ].include?(default)
      raise ConfigurationError,
            "feature_flags.#{name}: 'default' must be a Boolean (true or false), got #{default.inspect}"
    end
  end
end
