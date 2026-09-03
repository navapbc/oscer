# frozen_string_literal: true

require "rails_helper"

RSpec.describe Certifications::RequirementParams do
  describe "#months_that_can_be_certified" do
    subject(:months) { params.months_that_can_be_certified }

    let(:certification_date) { Date.new(2026, 8, 20) }
    let(:cert_date_start) { certification_date.beginning_of_month }
    let(:params) do
      build(
        :certification_certification_requirement_params,
        certification_date:,
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
        expect(months).not_to include cert_date_start
      end
    end

    context "with a single-month lookback" do
      let(:lookback_period) { 1 }

      it "returns only the month before the certification month" do
        expect(months).to eq [ cert_date_start << 1 ]
      end
    end

    context "when the window crosses a year boundary" do
      let(:lookback_period) { 2 }

      let(:certification_date) { Date.new(2026, 1, 15) }

      it "walks back into the previous year" do
        expect(months).to eq [ Date.new(2025, 12, 1), Date.new(2025, 11, 1) ]
      end
    end
  end

  describe "#to_requirements" do
    subject(:requirements) { params.to_requirements }

    let(:lookback_period) { 6 }
    let(:certification_date) { Date.new(2026, 8, 20) }
    let(:expected_start) { certification_date.beginning_of_month << lookback_period }
    let(:expected_end) { certification_date.beginning_of_month << 1 }

    let(:params) do
      build(
        :certification_certification_requirement_params,
        certification_date:,
        lookback_period:,
        number_of_months_to_certify: 3,
        due_period_days: 30
      )
    end

    it "carries the shifted months" do
      expect(requirements.months_that_can_be_certified.min).to eq expected_start
      expect(requirements.months_that_can_be_certified.max).to eq expected_end
    end

    it "produces a continuous lookback period ending the month before the certification month" do
      lookback = requirements.continuous_lookback_period

      expect(lookback.start).to eq expected_start
      expect(lookback.end).to eq expected_end
    end
  end

  describe "#to_requirements certification period bounds" do
    subject(:requirements) { params.to_requirements }

    # Coverage runs Jan to Jun and the renewal is requested in May, so the period
    # supplied is the currently active one, not the upcoming one.
    let(:certification_date) { Date.new(2026, 5, 20) }
    let(:params) do
      build(
        :certification_certification_requirement_params, :with_direct_params,
        certification_date:,
        **overrides
      )
    end
    let(:overrides) { {} }

    it "leaves both bounds nil when the request does not supply them" do
      expect(requirements.certification_period_start).to be_nil
      expect(requirements.certification_period_end).to be_nil
    end

    context "when the request supplies the period bounds" do
      let(:overrides) do
        {
          certification_period_start: Date.new(2026, 1, 1),
          certification_period_end: Date.new(2026, 6, 30)
        }
      end

      it "carries the supplied start through" do
        expect(requirements.certification_period_start).to eq Date.new(2026, 1, 1)
      end

      it "carries the supplied end through" do
        expect(requirements.certification_period_end).to eq Date.new(2026, 6, 30)
      end
    end
  end

  describe "due date" do
    # The API reaches these callbacks through UnionObject.new, which calls valid?
    # as its type dispatch. Validating here is what production actually does.
    subject(:requirements) do
      params.valid?
      params.to_requirements
    end

    # Sits well away from today, so anchoring on the certification date is
    # distinguishable from anchoring on the day the request is processed.
    let(:certification_date) { Date.new(2026, 11, 20) }

    around { |example| freeze_time { example.run } }

    context "when the request supplies a due date" do
      let(:params) do
        build(
          :certification_certification_requirement_params,
          certification_date:,
          certification_type: "recertification",
          due_date: Date.new(2026, 12, 15)
        )
      end

      it "keeps the supplied due date" do
        expect(requirements.due_date).to eq Date.new(2026, 12, 15)
      end
    end

    context "when the request supplies no due date" do
      let(:params) do
        build(
          :certification_certification_requirement_params,
          certification_date:,
          certification_type: "recertification"
        )
      end

      it "sets the due date the configured number of days from the processing date" do
        expect(requirements.due_date).to eq Date.current + 30.days
      end
    end

    context "when the due period comes from the batch or demo path instead of a type" do
      let(:params) do
        build(
          :certification_certification_requirement_params, :with_direct_params,
          certification_date:,
          due_period_days: 45
        )
      end

      it "offsets by the configured due period from the processing date" do
        expect(requirements.due_date).to eq Date.current + 45.days
      end
    end

    context "when the request supplies an explicit null due period" do
      let(:params) do
        build(
          :certification_certification_requirement_params,
          certification_date:,
          lookback_period: 6,
          number_of_months_to_certify: 3,
          due_period_days: nil
        )
      end

      # An explicit null beats the attribute default, so the fallback has to
      # carry the default itself rather than rely on the attribute.
      it "still offsets by the default due period" do
        expect(requirements.due_date).to eq Date.current + 30.days
      end
    end

    context "when the request supplies a certification type and its own due period" do
      let(:params) do
        build(
          :certification_certification_requirement_params,
          certification_date:,
          certification_type: "recertification",
          due_period_days: 45
        )
      end

      it "discards the supplied due period in favor of the default" do
        expect(requirements.due_date).to eq Date.current + 30.days
      end
    end

    context "when the request supplies a due date that is not a date" do
      subject(:validity) { params.valid? }

      [
        [ "an array", [ "2026-12-15" ] ],
        [ "an integer", 12_345 ],
        [ "a boolean", true ]
      ].each do |label, value|
        context "when it is #{label}" do
          let(:params) do
            described_class.new_filtered(
              "certification_date" => certification_date,
              "certification_type" => "recertification",
              "due_date" => value
            )
          end

          it "rejects the request" do
            expect(validity).to be false
            expect(params.errors).to include(:due_date)
          end
        end
      end
    end

    context "when the request supplies neither a due date nor a due period" do
      let(:params) do
        build(
          :certification_certification_requirement_params,
          certification_date:,
          lookback_period: 6,
          number_of_months_to_certify: 3
        )
      end

      it "accepts the request and offsets by the default due period" do
        expect(requirements.due_date).to eq Date.current + 30.days
      end

      it "no longer rejects the request for having neither field" do
        expect(params).to be_valid
      end
    end
  end
end
