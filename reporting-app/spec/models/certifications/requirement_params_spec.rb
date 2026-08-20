# frozen_string_literal: true

require "rails_helper"

RSpec.describe Certifications::RequirementParams do
  describe "#months_that_can_be_certified" do
    subject(:months) { params.months_that_can_be_certified }

    let(:params) do
      build(
        :certification_certification_requirement_params,
        certification_date: Date.new(2026, 8, 20),
        lookback_period: lookback_period,
        number_of_months_to_certify: 1,
        due_period_days: 30
      )
    end

    context "with a multi-month lookback" do
      let(:lookback_period) { 3 }

      it "returns the lookback_period months ending the month before the certification month" do
        expect(months).to eq [ Date.new(2026, 7, 1), Date.new(2026, 6, 1), Date.new(2026, 5, 1) ]
      end

      it "excludes the certification month" do
        expect(months).not_to include Date.new(2026, 8, 1)
      end
    end

    context "with a single-month lookback" do
      let(:lookback_period) { 1 }

      it "returns only the month before the certification month" do
        expect(months).to eq [ Date.new(2026, 7, 1) ]
      end
    end

    context "when the window crosses a year boundary" do
      let(:params) do
        build(
          :certification_certification_requirement_params,
          certification_date: Date.new(2026, 1, 15),
          lookback_period: 2,
          number_of_months_to_certify: 1,
          due_period_days: 30
        )
      end

      it "walks back into the previous year" do
        expect(months).to eq [ Date.new(2025, 12, 1), Date.new(2025, 11, 1) ]
      end
    end
  end

  describe "#to_requirements" do
    subject(:requirements) { params.to_requirements }

    let(:params) do
      build(
        :certification_certification_requirement_params,
        certification_date: Date.new(2026, 8, 20),
        lookback_period: 6,
        number_of_months_to_certify: 3,
        due_period_days: 30
      )
    end

    it "carries the shifted months" do
      expect(requirements.months_that_can_be_certified.max).to eq Date.new(2026, 7, 1)
      expect(requirements.months_that_can_be_certified.min).to eq Date.new(2026, 2, 1)
    end

    it "produces a continuous lookback period ending the month before the certification month" do
      lookback = requirements.continuous_lookback_period

      expect(lookback.start).to eq Date.new(2026, 2, 1)
      expect(lookback.end).to eq Date.new(2026, 7, 1)
    end
  end
end
