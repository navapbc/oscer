# frozen_string_literal: true

# Helper module for checking feature flags in controllers and views
module FeatureFlagHelper
  # Check if a feature is enabled
  # @param feature [Symbol] the feature to check
  # @return [Boolean] true if the feature is enabled
  def feature_enabled?(feature)
    case feature
    when :batch_upload_v2
      Features.batch_upload_v2_enabled?
    else
      false
    end
  end
end
