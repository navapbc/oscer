# frozen_string_literal: true

# Helper module for checking feature flags in controllers and views
module FeatureFlagHelper
  # Check if a feature is enabled
  # @param feature [Symbol] the feature to check
  # @return [Boolean] true if the feature is enabled
  def feature_enabled?(feature)
    Features.enabled?(feature)
  rescue ArgumentError
    # Unknown feature - log warning and return false
    Rails.logger.warn("Unknown feature flag checked: #{feature}")
    false
  end
end
