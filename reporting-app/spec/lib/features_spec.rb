# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Features do
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
end
