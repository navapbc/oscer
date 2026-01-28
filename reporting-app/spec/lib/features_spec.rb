# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Features do
  describe 'FEATURE_FLAGS' do
    it 'defines all expected flags' do
      expect(described_class::FEATURE_FLAGS).to be_a(Hash)
      expect(described_class::FEATURE_FLAGS).to be_frozen
      expect(described_class::FEATURE_FLAGS.keys).to include(:batch_upload_v2)
    end

    it 'each flag has required configuration' do
      described_class::FEATURE_FLAGS.each do |_flag_name, config|
        expect(config).to have_key(:env_var)
        expect(config).to have_key(:default)
        expect(config[:env_var]).to be_a(String)
        expect(config[:default]).to be_in([ true, false ])
      end
    end
  end

  describe '.batch_upload_v2_enabled?' do
    it 'defaults to false' do
      # Ensure ENV is not set (or set to false)
      original = ENV['FEATURE_BATCH_UPLOAD_V2']
      ENV['FEATURE_BATCH_UPLOAD_V2'] = nil
      expect(described_class.batch_upload_v2_enabled?).to be false
      ENV['FEATURE_BATCH_UPLOAD_V2'] = original
    end

    it 'returns true when ENV is set to "true"' do
      with_batch_upload_v2_enabled do
        expect(described_class.batch_upload_v2_enabled?).to be true
      end
    end

    it 'returns false when ENV is set to "false"' do
      with_batch_upload_v2_disabled do
        expect(described_class.batch_upload_v2_enabled?).to be false
      end
    end
  end

  describe '.enabled?' do
    it 'returns correct value for registered flags' do
      with_batch_upload_v2_enabled do
        expect(described_class.enabled?(:batch_upload_v2)).to be true
      end
    end

    it 'raises ArgumentError for unknown flags' do
      expect do
        described_class.enabled?(:unknown_feature)
      end.to raise_error(ArgumentError, /Unknown feature flag: unknown_feature/)
    end
  end

  describe '.all_flags' do
    it 'returns array of all registered flag names' do
      flags = described_class.all_flags
      expect(flags).to be_an(Array)
      expect(flags).to include(:batch_upload_v2)
    end
  end

  describe '.flag_config' do
    it 'returns configuration for a flag' do
      config = described_class.flag_config(:batch_upload_v2)
      expect(config).to be_a(Hash)
      expect(config[:env_var]).to eq("FEATURE_BATCH_UPLOAD_V2")
      expect(config[:default]).to be false
    end
  end
end
