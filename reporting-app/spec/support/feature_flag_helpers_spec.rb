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

  describe '#with_batch_upload_v2_enabled' do
    it 'enables the feature for the duration of the block' do
      test_instance.with_batch_upload_v2_enabled do
        expect(Features.batch_upload_v2_enabled?).to be true
      end
    end

    it 'restores original value after block' do
      original = ENV['FEATURE_BATCH_UPLOAD_V2']

      test_instance.with_batch_upload_v2_enabled do
        expect(Features.batch_upload_v2_enabled?).to be true
      end

      expect(ENV['FEATURE_BATCH_UPLOAD_V2']).to eq original
    end

    it 'restores original value even if error occurs' do
      ENV['FEATURE_BATCH_UPLOAD_V2'] = 'false'

      expect do
        test_instance.with_batch_upload_v2_enabled do
          expect(Features.batch_upload_v2_enabled?).to be true
          raise StandardError, 'Test error'
        end
      end.to raise_error(StandardError)

      expect(Features.batch_upload_v2_enabled?).to be false
    end
  end

  describe '#with_batch_upload_v2_disabled' do
    it 'disables the feature for the duration of the block' do
      test_instance.with_batch_upload_v2_disabled do
        expect(Features.batch_upload_v2_enabled?).to be false
      end
    end

    it 'restores original value after block' do
      original = ENV['FEATURE_BATCH_UPLOAD_V2']

      test_instance.with_batch_upload_v2_disabled do
        expect(Features.batch_upload_v2_enabled?).to be false
      end

      expect(ENV['FEATURE_BATCH_UPLOAD_V2']).to eq original
    end
  end
end
