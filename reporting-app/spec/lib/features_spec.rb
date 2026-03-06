# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Features do
  describe 'FEATURE_FLAGS' do
    it 'is a frozen Hash' do
      expect(described_class::FEATURE_FLAGS).to be_a(Hash)
      expect(described_class::FEATURE_FLAGS).to be_frozen
    end
  end

  describe '.enabled?' do
    it 'raises ArgumentError for unknown flags' do
      expect do
        described_class.enabled?(:unknown_feature)
      end.to raise_error(ArgumentError, /Unknown feature flag: unknown_feature/)
    end
  end

  describe '.all_flags' do
    it 'returns an array' do
      flags = described_class.all_flags
      expect(flags).to be_an(Array)
    end
  end

  describe '.flag_config' do
    it 'returns nil for unknown flags' do
      expect(described_class.flag_config(:nonexistent)).to be_nil
    end
  end
end
