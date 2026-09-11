# frozen_string_literal: true

require "rails_helper"

RSpec.describe Determinations::ExternalCECombinedDeterminationData do
  let(:expected_calculated_at) { Time.zone.parse("2026-04-30 15:00:00").iso8601 }

  let(:empty_hours_data) do
    {
      total_hours: 0,
      hours_by_category: {},
      hours_by_source: { external: 0.0, activity: 0.0 },
      external_hourly_activity_ids: [],
      activity_ids: []
    }
  end
  let(:empty_income_data) do
    {
      total_income: BigDecimal("0"),
      income_by_source: { external: BigDecimal("0"), activity: BigDecimal("0") },
      period_start: nil,
      period_end: nil,
      external_income_activity_ids: [],
      activity_ids: []
    }
  end

  around do |example|
    travel_to(Time.zone.parse(expected_calculated_at)) { example.run }
  end

  it "serializes a stable external_ce_combined payload with satisfied_by both when both tracks pass" do
    hours_data = {
      total_hours: 80,
      hours_by_category: { "employment" => 80.0 },
      hours_by_source: { external: 80.0, activity: 0.0 },
      external_hourly_activity_ids: [ "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" ],
      activity_ids: []
    }
    income_data = {
      total_income: BigDecimal("600"),
      income_by_source: { external: BigDecimal("600"), activity: BigDecimal("0") },
      period_start: Date.new(2026, 2, 1),
      period_end: Date.new(2026, 2, 28),
      external_income_activity_ids: [ "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb" ],
      activity_ids: []
    }

    payload = described_class.build(
      hours_data: hours_data,
      income_data: income_data,
      hours_ok: true,
      income_ok: true
    ).to_h

    expect(payload["calculation_type"]).to eq(Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED)
    expect(payload["satisfied_by"]).to eq(Determination::SATISFIED_BY_BOTH)
    expect(payload["hours"]["compliant"]).to be true
    expect(payload["income"]["compliant"]).to be true
    expect(payload["calculated_at"]).to eq(expected_calculated_at)

    expect(payload["hours"]).to eq(
      Determinations::HoursBasedDeterminationData.from_aggregate(hours_data, compliant: true).to_h
    )
    expect(payload["income"]).to eq(
      Determinations::IncomeBasedDeterminationData.from_aggregate(income_data, compliant: true).to_h
    )
  end

  it "uses satisfied_by hours when only the hours track passes" do
    hours_data = {
      total_hours: 80,
      hours_by_category: { "employment" => 80.0 },
      hours_by_source: { external: 80.0, activity: 0.0 },
      external_hourly_activity_ids: [ "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" ],
      activity_ids: []
    }
    income_data = {
      total_income: BigDecimal("0"),
      income_by_source: { external: BigDecimal("0"), activity: BigDecimal("0") },
      period_start: nil,
      period_end: nil,
      external_income_activity_ids: [],
      activity_ids: []
    }

    payload = described_class.build(
      hours_data: hours_data,
      income_data: income_data,
      hours_ok: true,
      income_ok: false
    ).to_h

    expect(payload["satisfied_by"]).to eq(Determination::SATISFIED_BY_HOURS)
    expect(payload["hours"]["compliant"]).to be true
    expect(payload["income"]["compliant"]).to be false
  end

  it "uses satisfied_by income when only the income track passes" do
    hours_data = {
      total_hours: 0,
      hours_by_category: {},
      hours_by_source: { external: 0.0, activity: 0.0 },
      external_hourly_activity_ids: [],
      activity_ids: []
    }
    income_data = {
      total_income: BigDecimal("600"),
      income_by_source: { external: BigDecimal("600"), activity: BigDecimal("0") },
      period_start: Date.new(2026, 2, 1),
      period_end: Date.new(2026, 2, 28),
      external_income_activity_ids: [ "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb" ],
      activity_ids: []
    }

    payload = described_class.build(
      hours_data: hours_data,
      income_data: income_data,
      hours_ok: false,
      income_ok: true
    ).to_h

    expect(payload["satisfied_by"]).to eq(Determination::SATISFIED_BY_INCOME)
    expect(payload["hours"]["compliant"]).to be false
    expect(payload["income"]["compliant"]).to be true
  end

  it "uses satisfied_by neither when both tracks fail" do
    hours_data = {
      total_hours: 0,
      hours_by_category: {},
      hours_by_source: { external: 0.0, activity: 0.0 },
      external_hourly_activity_ids: [],
      activity_ids: []
    }
    income_data = {
      total_income: BigDecimal("0"),
      income_by_source: { external: BigDecimal("0"), activity: BigDecimal("0") },
      period_start: nil,
      period_end: nil,
      external_income_activity_ids: [],
      activity_ids: []
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

  # No fallback aggregate was computed, so there is no third track to serialize.
  it "omits the combined_hours payload when no combined aggregate is given" do
    payload = described_class.build(
      hours_data: empty_hours_data,
      income_data: empty_income_data,
      hours_ok: false,
      income_ok: false
    ).to_h

    expect(payload).not_to have_key("combined_hours")
  end

  it "uses satisfied_by combined_hours when only the combined track passes" do
    combined_hours_data = {
      total_hours: 95,
      hours_by_category: { "employment" => 55.0, "community_service" => 40.0 },
      hours_by_source: { external: 95.0, activity: 0.0 },
      external_hourly_activity_ids: [ "cccccccc-cccc-4ccc-8ccc-cccccccccccc" ],
      activity_ids: []
    }

    payload = described_class.build(
      hours_data: empty_hours_data,
      income_data: empty_income_data,
      hours_ok: false,
      income_ok: false,
      combined_hours_data: combined_hours_data,
      combined_hours_ok: true
    ).to_h

    expect(payload["satisfied_by"]).to eq(Determination::SATISFIED_BY_COMBINED_HOURS)
    expect(payload["hours"]["compliant"]).to be false
    expect(payload["income"]["compliant"]).to be false
    expect(payload["combined_hours"]).to eq(
      Determinations::HoursBasedDeterminationData.from_aggregate(combined_hours_data, compliant: true).to_h
    )
  end

  # A verdict with nothing behind it would put a compliant determination on an empty payload.
  it "fails at build time when the combined track passes with no aggregate" do
    expect {
      described_class.build(
        hours_data: empty_hours_data,
        income_data: empty_income_data,
        hours_ok: false,
        income_ok: false,
        combined_hours_ok: true
      )
    }.to raise_error(ActiveModel::ValidationError)
  end

  # The reverse: figures no verdict was drawn from have no business in the payload.
  it "fails at build time when a combined aggregate arrives with no verdict" do
    expect {
      described_class.build(
        hours_data: empty_hours_data,
        income_data: empty_income_data,
        hours_ok: false,
        income_ok: false,
        combined_hours_data: empty_hours_data
      )
    }.to raise_error(ActiveModel::ValidationError)
  end

  it "fails at build time when nested hours aggregate is invalid" do
    invalid_hours = { not_an_aggregate: true }
    valid_income = {
      total_income: BigDecimal("0"),
      income_by_source: { external: BigDecimal("0"), activity: BigDecimal("0") },
      period_start: nil,
      period_end: nil,
      external_income_activity_ids: [],
      activity_ids: []
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

  it "requires .build before #to_h so nested VOs are populated" do
    hours_data = {
      total_hours: 0,
      hours_by_category: {},
      hours_by_source: { external: 0.0, activity: 0.0 },
      external_hourly_activity_ids: [],
      activity_ids: []
    }
    income_data = {
      total_income: BigDecimal("0"),
      income_by_source: { external: BigDecimal("0"), activity: BigDecimal("0") },
      period_start: nil,
      period_end: nil,
      external_income_activity_ids: [],
      activity_ids: []
    }

    vo = described_class.new(
      hours_data: hours_data,
      income_data: income_data,
      hours_ok: false,
      income_ok: false,
      calculated_at: expected_calculated_at
    )

    expect { vo.to_h }.to raise_error(ArgumentError, /\.build/)
  end
end
