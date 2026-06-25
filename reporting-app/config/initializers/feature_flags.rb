# frozen_string_literal: true

# Zeitwerk autoloading is not available during initializers, so require the
# loader explicitly (same pattern as config/initializers/exemption_types.rb).
require Rails.root.join("app/services/feature_flags_loader")

# Feature flag system for controlling feature rollout
# Flags are controlled via environment variables.
#
# There are two sources of flags:
#
#   1. OSCER-shipped built-ins — declared in FEATURE_FLAGS below. OSCER-owned.
#      To add one, add an entry to FEATURE_FLAGS:
#        my_feature: { env_var: "FEATURE_MY_FEATURE", default: false }
#
#   2. Deployment-defined flags — declared in config/custom/feature_flags.yml,
#      the deployment-owned override surface. These let a deployment add its own
#      flags without editing this OSCER-owned file (which would conflict on
#      every upstream sync). See CUSTOMIZATION.md (Config) and that YAML file's
#      header for the entry shape.
#
# Both sources are unioned into REGISTRY at boot (see below). The deployment
# override is ADDITIVE ONLY: a YAML entry that collides with a built-in raises
# a ConfigurationError at boot — toggle a built-in via its env var instead.
#
# Every registered flag (built-in or deployment-defined) automatically gets:
#   - Features.my_feature_enabled? method
#   - Features.enabled?(:my_feature) generic method
#   - with_my_feature_enabled test helper
#   - with_my_feature_disabled test helper
module Features
  # Registry of OSCER-shipped built-in feature flags.
  # Deployment-defined flags are NOT added here; they live in
  # config/custom/feature_flags.yml and are merged into REGISTRY at boot.
  FEATURE_FLAGS = {
    doc_ai: {
      env_var: "FEATURE_DOC_AI",
      default: false,
      description: "Enable DocAI document analysis for income verification"
    }
    # Example of adding more built-in flags:
    # realtime_progress: {
    #   env_var: "FEATURE_REALTIME_PROGRESS",
    #   default: false,
    #   description: "Enable WebSocket real-time progress updates"
    # },
  }.freeze

  # Merged registry: OSCER-shipped built-ins unioned with the deployment's
  # optional feature_flags.yml entries. Built at boot, BEFORE the
  # method-generation loop below, so deployment-defined flags get the same
  # generated *_enabled? methods (and, via FeatureFlagHelpers, the same
  # with_*_enabled/disabled test helpers). This is the canonical set every
  # public method below reads — FEATURE_FLAGS alone is just the built-ins.
  REGISTRY = FeatureFlagsLoader.build_registry(
    FEATURE_FLAGS,
    FeatureFlagsLoader.safe_load_optional(Rails.root.join("config/custom/feature_flags.yml"))
  ).freeze

  # Cached Boolean type instance for efficient casting
  BOOLEAN_TYPE = ActiveModel::Type::Boolean.new.freeze

  class << self
    # Dynamically define <feature>_enabled? methods for each flag in the merged
    # registry (built-ins + deployment-defined).
    REGISTRY.each do |flag_name, config|
      define_method("#{flag_name}_enabled?") do
        cast_to_boolean(config)
      end
    end

    # Generic method to check if any feature is enabled
    # @param flag_name [Symbol] the feature flag to check
    # @return [Boolean] true if the feature is enabled
    # @raise [ArgumentError] if flag_name is not a registered feature
    def enabled?(flag_name)
      unless REGISTRY.key?(flag_name)
        raise ArgumentError, "Unknown feature flag: #{flag_name}. " \
                            "Available flags: #{REGISTRY.keys.join(', ')}"
      end

      config = REGISTRY[flag_name]
      cast_to_boolean(config)
    end

    # List all registered feature flags (built-ins + deployment-defined)
    # @return [Array<Symbol>] array of feature flag names
    def all_flags
      REGISTRY.keys
    end

    # Get metadata about a feature flag
    # @param flag_name [Symbol] the feature flag
    # @return [Hash] configuration for the flag
    def flag_config(flag_name)
      REGISTRY[flag_name]
    end

    private

    # Cast an environment variable value to boolean using Rails type coercion
    # Handles many truthy formats: "true", "1", "t", "yes", "y", "on" (case-insensitive)
    # @param config [Hash] feature flag configuration with :env_var and :default keys
    # @return [Boolean] true if the value is truthy, false otherwise
    def cast_to_boolean(config)
      val = ENV.fetch(config[:env_var], config[:default])
      BOOLEAN_TYPE.cast(val) == true
    end
  end
end
