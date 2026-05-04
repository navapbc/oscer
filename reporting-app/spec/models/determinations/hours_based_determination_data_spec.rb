# frozen_string_literal: true

require "rails_helper"

RSpec.describe Determinations::HoursBasedDeterminationData do
  around do |example|
    travel_to(Time.zone.parse("2026-04-30 15:00:00")) { example.run }
  end

  let(:calculated_at) { Time.zone.parse("2026-04-30 15:00:00").iso8601 }

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

  it "omits compliant from the hash when not passed (standalone hours CE)" do
    hours_data = {
      total_hours: 10,
      hours_by_category: {},
      hours_by_source: { ex_parte: 10.0, activity: 0.0 },
      ex_parte_activity_ids: [],
      activity_ids: []
    }

    h = described_class.from_aggregate(hours_data).to_h
    expect(h).not_to have_key("compliant")
  end
end
