# frozen_string_literal: true

require "rails_helper"

RSpec.describe Determinations do
  around do |example|
    travel_to(Time.zone.parse("2026-04-30 15:00:00")) { example.run }
  end

  let(:calculated_at) { Time.zone.parse("2026-04-30 15:00:00").iso8601 }

  describe Determinations::HoursBasedDeterminationData do
    it "serializes a stable hours_based payload" do
      hours_data = {
        total_hours: 85,
        hours_by_category: { "employment" => 40.0, "education" => 45.0 },
        hours_by_source: { ex_parte: 85.0, activity: 0.0 },
        ex_parte_activity_ids: [ "11111111-1111-4111-8111-111111111111" ],
        activity_ids: []
      }

      expect(described_class.from_aggregate(hours_data).to_h).to eq(
        {
          "calculation_type" => Determination::CALCULATION_TYPE_HOURS_BASED,
          "total_hours" => 85.0,
          "target_hours" => HoursComplianceDeterminationService::TARGET_HOURS,
          "hours_by_category" => { "employment" => 40.0, "education" => 45.0 },
          "hours_by_source" => { "ex_parte" => 85.0, "activity" => 0.0 },
          "ex_parte_activity_ids" => [ "11111111-1111-4111-8111-111111111111" ],
          "activity_ids" => [],
          "calculated_at" => calculated_at
        }
      )
    end

    it "includes compliant in the hash when provided for combined CE nesting" do
      hours_data = {
        total_hours: 10,
        hours_by_category: {},
        hours_by_source: { ex_parte: 10.0, activity: 0.0 },
        ex_parte_activity_ids: [],
        activity_ids: []
      }

      h = described_class.from_aggregate(hours_data, compliant: false).to_h
      expect(h["compliant"]).to be false
    end
  end

  describe Determinations::IncomeBasedDeterminationData do
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

  describe Determinations::CECombinedDeterminationData do
    it "serializes a stable ce_combined payload" do
      hours_data = {
        total_hours: 80,
        hours_by_category: { "employment" => 80.0 },
        hours_by_source: { ex_parte: 80.0, activity: 0.0 },
        ex_parte_activity_ids: [ "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" ],
        activity_ids: []
      }
      income_data = {
        total_income: BigDecimal("600"),
        income_by_source: { income: BigDecimal("600"), activity: BigDecimal("0") },
        period_start: Date.new(2026, 2, 1),
        period_end: Date.new(2026, 2, 28),
        income_ids: [ "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb" ]
      }

      payload = described_class.build(
        hours_data: hours_data,
        income_data: income_data,
        hours_ok: true,
        income_ok: true
      ).to_h

      expect(payload["calculation_type"]).to eq(Determination::CALCULATION_TYPE_CE_COMBINED)
      expect(payload["satisfied_by"]).to eq(Determination::SATISFIED_BY_BOTH)
      expect(payload["calculated_at"]).to eq(calculated_at)

      expect(payload["hours"]).to eq(
        Determinations::HoursBasedDeterminationData.from_aggregate(hours_data, compliant: true).to_h
      )
      expect(payload["income"]).to eq(
        Determinations::IncomeBasedDeterminationData.from_aggregate(income_data, compliant: true).to_h
      )
    end

    it "uses satisfied_by neither when both tracks fail" do
      hours_data = {
        total_hours: 0,
        hours_by_category: {},
        hours_by_source: { ex_parte: 0.0, activity: 0.0 },
        ex_parte_activity_ids: [],
        activity_ids: []
      }
      income_data = {
        total_income: BigDecimal("0"),
        income_by_source: { income: BigDecimal("0"), activity: BigDecimal("0") },
        period_start: nil,
        period_end: nil,
        income_ids: []
      }

      payload = described_class.build(
        hours_data: hours_data,
        income_data: income_data,
        hours_ok: false,
        income_ok: false
      ).to_h

      expect(payload["satisfied_by"]).to eq(Determination::SATISFIED_BY_NEITHER)
      expect(payload["hours"]["compliant"]).to be false
      expect(payload["income"]["compliant"]).to be false
    end
  end
end
