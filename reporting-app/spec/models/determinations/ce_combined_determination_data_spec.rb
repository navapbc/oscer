# frozen_string_literal: true

require "rails_helper"

RSpec.describe Determinations::CECombinedDeterminationData do
  around do |example|
    travel_to(Time.zone.parse("2026-04-30 15:00:00")) { example.run }
  end

  let(:calculated_at) { Time.zone.parse("2026-04-30 15:00:00").iso8601 }

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

  it "fails at build time when nested hours aggregate is invalid" do
    invalid_hours = { not_an_aggregate: true }
    valid_income = {
      total_income: BigDecimal("0"),
      income_by_source: { income: BigDecimal("0"), activity: BigDecimal("0") },
      period_start: nil,
      period_end: nil,
      income_ids: []
    }

    expect {
      described_class.build(
        hours_data: invalid_hours,
        income_data: valid_income,
        hours_ok: false,
        income_ok: false
      )
    }.to raise_error(ActiveModel::ValidationError)
  end
end
