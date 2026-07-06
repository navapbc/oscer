# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Features do
  describe 'FEATURE_FLAGS' do
    it 'is a frozen Hash' do
      expect(described_class::FEATURE_FLAGS).to be_a(Hash)
      expect(described_class::FEATURE_FLAGS).to be_frozen
    end

    it 'holds the OSCER-shipped built-ins (doc_ai)' do
      expect(described_class::FEATURE_FLAGS.keys).to include(:doc_ai)
    end

    it 'registers demo_certifications with the expected env var and default off' do
      expect(described_class::FEATURE_FLAGS[:demo_certifications]).to include(
        env_var: 'FEATURE_DEMO_CERTIFICATIONS',
        default: false
      )
    end
  end

  describe 'REGISTRY' do
    it 'is a frozen Hash' do
      expect(described_class::REGISTRY).to be_a(Hash)
      expect(described_class::REGISTRY).to be_frozen
    end

    it 'includes every OSCER-shipped built-in' do
      expect(described_class::REGISTRY.keys).to include(*described_class::FEATURE_FLAGS.keys)
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

    it 'returns the config for a built-in flag' do
      expect(described_class.flag_config(:doc_ai)).to include(env_var: 'FEATURE_DOC_AI')
    end
  end

  # The <name>_enabled? methods are metaprogrammed uniformly over REGISTRY (see
  # config/initializers/feature_flags.rb) with no branch on built-in vs
  # deployment-defined — so a built-in flag exercises the exact same generation
  # path a deployment-defined flag would. We test it here against the live
  # built-in (doc_ai). That deployment-defined flags land in REGISTRY with the
  # same shape is proven in spec/services/feature_flags_loader_spec.rb
  # (.build_registry), and that they receive with_*_enabled/disabled helpers in
  # spec/support/feature_flag_helpers_spec.rb.
  describe 'generated <name>_enabled? methods' do
    around do |example|
      original = ENV['FEATURE_DOC_AI']
      example.run
    ensure
      ENV['FEATURE_DOC_AI'] = original
    end

    it 'generates a <name>_enabled? method for each registered flag' do
      expect(described_class).to respond_to(:doc_ai_enabled?)
    end

    it 'honors the env var when it is set' do
      ENV['FEATURE_DOC_AI'] = 'true'
      expect(described_class.doc_ai_enabled?).to be true
    end

    it 'falls back to the registered default when the env var is unset' do
      ENV.delete('FEATURE_DOC_AI')
      expect(described_class.doc_ai_enabled?).to be false
    end

    it 'answers the generic enabled? for a registered flag' do
      ENV['FEATURE_DOC_AI'] = 'true'
      expect(described_class.enabled?(:doc_ai)).to be true
    end
  end
end
