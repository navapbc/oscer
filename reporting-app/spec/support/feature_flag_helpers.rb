# frozen_string_literal: true

# Test helpers for feature flags
# These helpers manipulate ENV directly and are ONLY safe in test environment
#
# Helpers are automatically generated for each flag in Features::FEATURE_FLAGS
# For example, batch_upload_v2 flag gets:
#   - with_batch_upload_v2_enabled { }
#   - with_batch_upload_v2_disabled { }
module FeatureFlagHelpers
  # Dynamically generate with_<feature>_enabled/disabled helpers for each flag
  Features::FEATURE_FLAGS.each do |flag_name, config|
    # Generate: with_batch_upload_v2_enabled { }
    define_method("with_#{flag_name}_enabled") do |&block|
      with_env(config[:env_var], "true", &block)
    end

    # Generate: with_batch_upload_v2_disabled { }
    define_method("with_#{flag_name}_disabled") do |&block|
      with_env(config[:env_var], "false", &block)
    end
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
