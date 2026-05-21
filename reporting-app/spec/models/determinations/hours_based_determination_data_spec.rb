# frozen_string_literal: true

require "rails_helper"

RSpec.describe Determinations::HoursBasedDeterminationData do
  let(:expected_calculated_at) { Time.zone.parse("2026-04-30 15:00:00").iso8601 }

  around do |example|
    travel_to(Time.zone.parse(expected_calculated_at)) { example.run }
  end

  it "serializes a stable hours_based payload" do
    hours_data = {
      total_hours: 85,
      hours_by_category: { "employment" => 40.0, "education" => 45.0 },
      hours_by_source: { external: 85.0, activity: 0.0 },
      external_hourly_activity_ids: [ "11111111-1111-4111-8111-111111111111" ],
      activity_ids: []
    }

    expect(described_class.from_aggregate(hours_data).to_h).to eq(
      {
        "calculation_type" => Determination::CALCULATION_TYPE_HOURS_BASED,
        "total_hours" => 85.0,
        "target_hours" => HoursComplianceDeterminationService::TARGET_HOURS,
        "hours_by_category" => { "employment" => 40.0, "education" => 45.0 },
        "hours_by_source" => { "external" => 85.0, "activity" => 0.0 },
        "external_hourly_activity_ids" => [ "11111111-1111-4111-8111-111111111111" ],
        "activity_ids" => [],
        "calculated_at" => expected_calculated_at
      }
    )
  end

  it "includes compliant in the hash when provided for combined CE nesting" do
    hours_data = {
      total_hours: 10,
      hours_by_category: {},
      hours_by_source: { external: 10.0, activity: 0.0 },
      external_hourly_activity_ids: [],
      activity_ids: []
    }

    h = described_class.from_aggregate(hours_data, compliant: false).to_h
    expect(h["compliant"]).to be false
  end

  it "omits compliant from the hash when not passed (standalone hours CE)" do
    hours_data = {
      total_hours: 10,
      hours_by_category: {},
      hours_by_source: { external: 10.0, activity: 0.0 },
      external_hourly_activity_ids: [],
      activity_ids: []
    }

    h = described_class.from_aggregate(hours_data).to_h
    expect(h).not_to have_key("compliant")
  end

  it "accepts string-keyed aggregate hashes" do
    hours_data = {
      "total_hours" => 85,
      "hours_by_category" => { "employment" => 40.0 },
      "hours_by_source" => { "external" => 85.0, "activity" => 0.0 },
      "external_hourly_activity_ids" => [ "11111111-1111-4111-8111-111111111111" ],
      "activity_ids" => []
    }

    expect(described_class.from_aggregate(hours_data).to_h["total_hours"]).to eq(85.0)
  end

  it "raises when total_hours is missing" do
    hours_data = {
      hours_by_category: {},
      hours_by_source: { external: 0.0, activity: 0.0 },
      external_hourly_activity_ids: [],
      activity_ids: []
    }

    expect {
      described_class.from_aggregate(hours_data)
    }.to raise_error(ActiveModel::ValidationError)
  end

  it "raises when total_hours is not numeric" do
    hours_data = {
      total_hours: "not-a-number",
      hours_by_category: {},
      hours_by_source: { external: 0.0, activity: 0.0 },
      external_hourly_activity_ids: [],
      activity_ids: []
    }

    expect {
      described_class.from_aggregate(hours_data)
    }.to raise_error(ActiveModel::ValidationError)
  end

  it "raises when hours_by_source is not a Hash" do
    hours_data = {
      total_hours: 10,
      hours_by_category: {},
      hours_by_source: "invalid",
      external_hourly_activity_ids: [],
      activity_ids: []
    }

    expect {
      described_class.from_aggregate(hours_data)
    }.to raise_error(ActiveModel::ValidationError)
  end

  it "raises when hours_by_category is not a Hash" do
    hours_data = {
      total_hours: 10,
      hours_by_category: "invalid",
      hours_by_source: { external: 10.0, activity: 0.0 },
      external_hourly_activity_ids: [],
      activity_ids: []
    }

    expect {
      described_class.from_aggregate(hours_data)
    }.to raise_error(ActiveModel::ValidationError)
  end
end
