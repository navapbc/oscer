# frozen_string_literal: true

# Test helpers for feature flags
# These helpers manipulate ENV directly and are ONLY safe in test environment
module FeatureFlagHelpers
  # Enable batch upload v2 feature for the duration of the block
  # @yield block to execute with the feature enabled
  def with_batch_upload_v2_enabled
    with_env("FEATURE_BATCH_UPLOAD_V2", "true") { yield }
  end

  # Disable batch upload v2 feature for the duration of the block
  # @yield block to execute with the feature disabled
  def with_batch_upload_v2_disabled
    with_env("FEATURE_BATCH_UPLOAD_V2", "false") { yield }
  end

  private

  # Helper to temporarily set an ENV variable
  # @param key [String] the environment variable name
  # @param value [String] the value to set
  # @yield block to execute with the ENV variable set
  def with_env(key, value)
    original = ENV[key]
    ENV[key] = value
    yield
  ensure
    ENV[key] = original
  end
end

RSpec.configure do |config|
  config.include FeatureFlagHelpers
end
