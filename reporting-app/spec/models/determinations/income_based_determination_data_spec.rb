# frozen_string_literal: true

require "rails_helper"

RSpec.describe Determinations::IncomeBasedDeterminationData do
  around do |example|
    travel_to(Time.zone.parse("2026-04-30 15:00:00")) { example.run }
  end

  let(:calculated_at) { Time.zone.parse("2026-04-30 15:00:00").iso8601 }

  it "serializes a stable income_based payload" do
    income_data = {
      total_income: BigDecimal("580.25"),
      income_by_source: { income: BigDecimal("500"), activity: BigDecimal("80.25") },
      period_start: Date.new(2026, 1, 1),
      period_end: Date.new(2026, 1, 31),
      income_ids: [ "22222222-2222-4222-8222-222222222222", "33333333-3333-4333-8333-333333333333" ]
    }

    expect(described_class.from_aggregate(income_data).to_h).to eq(
      {
        "calculation_type" => Determination::CALCULATION_TYPE_INCOME_BASED,
        "total_income" => 580.25,
        "target_income" => IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY.to_f,
        "income_by_source" => { "income" => 500.0, "activity" => 80.25 },
        "period_start" => "2026-01-01",
        "period_end" => "2026-01-31",
        "income_ids" => [ "22222222-2222-4222-8222-222222222222", "33333333-3333-4333-8333-333333333333" ],
        "calculation_method" => Determination::CALCULATION_METHOD_AUTOMATED_INCOME_INTAKE,
        "calculated_at" => calculated_at
      }
    )
  end
end
