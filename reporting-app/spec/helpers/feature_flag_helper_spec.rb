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
    context 'when checking batch_upload_v2' do
      it 'returns false when feature flag is disabled' do
        with_batch_upload_v2_disabled do
          expect(helper.feature_enabled?(:batch_upload_v2)).to be false
        end
      end

      it 'returns true when feature flag is enabled' do
        with_batch_upload_v2_enabled do
          expect(helper.feature_enabled?(:batch_upload_v2)).to be true
        end
      end
    end

    context 'when checking unknown feature' do
      it 'returns false and logs warning' do
        allow(Rails.logger).to receive(:warn)
        expect(helper.feature_enabled?(:unknown_feature)).to be false
        expect(Rails.logger).to have_received(:warn).with(/Unknown feature flag/)
      end
    end
  end
end
