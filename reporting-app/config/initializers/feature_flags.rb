# frozen_string_literal: true

# Feature flag system for controlling feature rollout
# Flags are controlled via environment variables
#
# To add a new feature flag, simply add an entry to FEATURE_FLAGS hash:
#   my_feature: { env_var: "FEATURE_MY_FEATURE", default: false }
#
# This automatically creates:
#   - Features.my_feature_enabled? method
#   - Features.enabled?(:my_feature) generic method
#   - with_my_feature_enabled test helper
#   - with_my_feature_disabled test helper
module Features
  # Registry of all feature flags
  # Add new flags here - methods are generated automatically
  FEATURE_FLAGS = {
    batch_upload_v2: {
      env_var: "FEATURE_BATCH_UPLOAD_V2",
      default: false,
      description: "Enable batch upload v2 with cloud storage and streaming"
    }
    # Example of adding more flags:
    # realtime_progress: {
    #   env_var: "FEATURE_REALTIME_PROGRESS",
    #   default: false,
    #   description: "Enable WebSocket real-time progress updates"
    # },
  }.freeze

  class << self
    # Dynamically define <feature>_enabled? methods for each flag
    FEATURE_FLAGS.each do |flag_name, config|
      define_method("#{flag_name}_enabled?") do
        ENV.fetch(config[:env_var], config[:default].to_s) == "true"
      end
    end

    # Generic method to check if any feature is enabled
    # @param flag_name [Symbol] the feature flag to check
    # @return [Boolean] true if the feature is enabled
    # @raise [ArgumentError] if flag_name is not a registered feature
    def enabled?(flag_name)
      unless FEATURE_FLAGS.key?(flag_name)
        raise ArgumentError, "Unknown feature flag: #{flag_name}. " \
                            "Available flags: #{FEATURE_FLAGS.keys.join(', ')}"
      end

      config = FEATURE_FLAGS[flag_name]
      ENV.fetch(config[:env_var], config[:default].to_s) == "true"
    end

    # List all registered feature flags
    # @return [Array<Symbol>] array of feature flag names
    def all_flags
      FEATURE_FLAGS.keys
    end

    # Get metadata about a feature flag
    # @param flag_name [Symbol] the feature flag
    # @return [Hash] configuration for the flag
    def flag_config(flag_name)
      FEATURE_FLAGS[flag_name]
    end
  end
end
