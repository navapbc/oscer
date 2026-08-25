# frozen_string_literal: true

require "rails_helper"

RSpec.describe Certifications::Requirements do
  let(:certification_date) { Date.new(2026, 5, 20) }

  # The certification period is supplied by the caller and never derived here. On a
  # recertification it is the member's currently active, expiring period; a new
  # application has none, because the member has no prior coverage period.
  describe "certification period bounds" do
    subject(:requirements) { build(:certification_certification_requirements, certification_date:, **overrides) }

    let(:overrides) { {} }

    it "leaves both bounds nil when the request does not supply them" do
      expect(requirements.certification_period_start).to be_nil
      expect(requirements.certification_period_end).to be_nil
    end

    it "adds no presence validation, so unsupplied bounds are still valid" do
      expect(requirements).to be_valid
    end

    context "when the request supplies the bounds" do
      let(:overrides) do
        {
          certification_period_start: Date.new(2026, 1, 1),
          certification_period_end: Date.new(2026, 6, 30)
        }
      end

      it "keeps the supplied start" do
        expect(requirements.certification_period_start).to eq Date.new(2026, 1, 1)
      end

      it "keeps the supplied end" do
        expect(requirements.certification_period_end).to eq Date.new(2026, 6, 30)
      end
    end
  end

  describe "supplied period bounds" do
    let(:bounds) do
      {
        "certification_period_start" => "2026-01-01",
        "certification_period_end" => "2026-06-30"
      }
    end

    it "survives a full-requirements request" do
      input = Api::Certifications::RequirementsOrParamsInput.new(
        bounds.merge(
          "certification_date" => "2026-05-20",
          "months_that_can_be_certified" => [ "2026-07-01" ]
        )
      )

      expect(input).to be_a(described_class)
      expect(input.certification_period_start).to eq Date.new(2026, 1, 1)
    end

    it "survives a parameter-shaped request" do
      input = Api::Certifications::RequirementsOrParamsInput.new(
        bounds.merge(
          "certification_date" => "2026-05-20",
          "lookback_period" => 6,
          "number_of_months_to_certify" => 3,
          "due_period_days" => 30
        )
      )

      expect(input).to be_a(Certifications::RequirementParams)
      expect(input.to_requirements.certification_period_start).to eq Date.new(2026, 1, 1)
    end

    it "survives batch upload input" do
      requirements = CertificationService.new.certification_requirements_from_input(
        bounds.merge(
          "certification_date" => "2026-05-20",
          "certification_type" => "new_application"
        )
      )

      expect(requirements.certification_period_start).to eq Date.new(2026, 1, 1)
    end

    it "survives a database round trip" do
      certification = create(
        :certification,
        certification_requirements: build(
          :certification_certification_requirements,
          certification_date:,
          certification_period_start: Date.new(2026, 1, 1),
          certification_period_end: Date.new(2026, 6, 30)
        )
      )

      stored = certification.reload.certification_requirements

      expect(stored.certification_period_start).to eq Date.new(2026, 1, 1)
      expect(stored.certification_period_end).to eq Date.new(2026, 6, 30)
    end
  end
end
