# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeatureFlagHelper do
  # Create a test class to include the helper
  let(:helper_class) do
    Class.new do
      include FeatureFlagHelper
    end
  end

  let(:helper) { helper_class.new }

  describe '#feature_enabled?' do
    context 'when checking unknown feature' do
      it 'returns false and logs warning' do
        allow(Rails.logger).to receive(:warn)
        expect(helper.feature_enabled?(:unknown_feature)).to be false
        expect(Rails.logger).to have_received(:warn).with(/Unknown feature flag/)
      end
    end
  end
end
