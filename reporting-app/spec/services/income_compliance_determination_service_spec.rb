# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncomeComplianceDeterminationService do
  let(:service_file) { Rails.root.join('app/services/income_compliance_determination_service.rb') }

  describe 'TARGET_INCOME_MONTHLY' do
    it 'defaults to 580' do
      expect(described_class::TARGET_INCOME_MONTHLY).to eq(BigDecimal('580'))
    end
  end

  describe 'CE_INCOME_THRESHOLD_MONTHLY validation at boot' do
    it 'raises and exits non-zero when set to zero' do
      output, status = capture_ruby_load_with_env({ 'CE_INCOME_THRESHOLD_MONTHLY' => '0' }, service_file)

      aggregate_failures do
        expect(status.success?).to be(false)
        expect(output).to include('CE_INCOME_THRESHOLD_MONTHLY must be positive')
      end
    end

    it 'raises and exits non-zero when set to a negative value' do
      output, status = capture_ruby_load_with_env({ 'CE_INCOME_THRESHOLD_MONTHLY' => '-1' }, service_file)

      aggregate_failures do
        expect(status.success?).to be(false)
        expect(output).to include('CE_INCOME_THRESHOLD_MONTHLY must be positive')
      end
    end
  end
end
