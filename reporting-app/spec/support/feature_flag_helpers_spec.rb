# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeatureFlagHelpers do
  # Create a test class that includes the helper
  let(:test_class) do
    Class.new do
      include FeatureFlagHelpers
    end
  end

  let(:test_instance) { test_class.new }

  describe 'with_temp_env_var helper' do
    it 'sets an ENV variable for the duration of a block and restores it' do
      env_key = "TEST_FEATURE_FLAG_HELPERS_SPEC"
      original = ENV[env_key]

      test_instance.send(:with_temp_env_var, env_key, "custom_value") do
        expect(ENV[env_key]).to eq("custom_value")
      end

      expect(ENV[env_key]).to eq(original)
    end

    it 'restores ENV variable even when block raises' do
      env_key = "TEST_FEATURE_FLAG_HELPERS_SPEC"
      ENV[env_key] = "before"

      expect do
        test_instance.send(:with_temp_env_var, env_key, "during") do
          expect(ENV[env_key]).to eq("during")
          raise StandardError, "test error"
        end
      end.to raise_error(StandardError)

      expect(ENV[env_key]).to eq("before")
    ensure
      ENV.delete(env_key)
    end
  end

  describe 'dynamic helper generation' do
    it 'generates enabled/disabled helpers for each registered flag' do
      Features::FEATURE_FLAGS.each_key do |flag_name|
        expect(test_instance).to respond_to("with_#{flag_name}_enabled")
        expect(test_instance).to respond_to("with_#{flag_name}_disabled")
      end
    end
  end
end
