# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CECompliance do
  describe '.fetch_income_threshold' do
    it 'defaults to 580' do
      expect(described_class.fetch_income_threshold).to eq(BigDecimal('580'))
    end

    it 'returns a custom positive value' do
      allow(ENV).to receive(:fetch).with('CE_INCOME_THRESHOLD_MONTHLY', '580').and_return('600')
      expect(described_class.fetch_income_threshold).to eq(BigDecimal('600'))
    end

    it 'raises ArgumentError when set to zero' do
      allow(ENV).to receive(:fetch).with('CE_INCOME_THRESHOLD_MONTHLY', '580').and_return('0')
      expect { described_class.fetch_income_threshold }
        .to raise_error(ArgumentError, /CE_INCOME_THRESHOLD_MONTHLY must be positive/)
    end

    it 'raises ArgumentError when set to a negative value' do
      allow(ENV).to receive(:fetch).with('CE_INCOME_THRESHOLD_MONTHLY', '580').and_return('-1')
      expect { described_class.fetch_income_threshold }
        .to raise_error(ArgumentError, /CE_INCOME_THRESHOLD_MONTHLY must be positive/)
    end
  end
end
