# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncomeComplianceDeterminationService do
  describe "TARGET_INCOME_MONTHLY" do
    it "defaults to 580" do
      expect(described_class::TARGET_INCOME_MONTHLY).to eq(BigDecimal("580"))
    end
  end
end
