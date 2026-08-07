# frozen_string_literal: true

require "rails_helper"

RSpec.describe Certifications::MemberData do
  describe Certifications::MemberData::Activity do
    describe "credit_hours validation" do
      subject(:activity) do
        described_class.new(
          type: "hourly",
          category: category,
          hours: 40,
          credit_hours: 9,
          period_start: Date.new(2025, 12, 1),
          period_end: Date.new(2025, 12, 31),
          verification_status: "verified"
        )
      end

      context "when the activity is an education activity" do
        let(:category) { "education" }

        it "is valid" do
          expect(activity).to be_valid
        end
      end

      context "when the activity is not an education activity" do
        let(:category) { "employment" }

        it "is invalid" do
          expect(activity).not_to be_valid
          expect(activity.errors).to be_of_kind(:credit_hours, :present)
        end
      end
    end

    describe "#clock_hours" do
      subject(:activity) do
        described_class.new(
          type: "hourly",
          category: category,
          hours: hours,
          credit_hours: credit_hours
        )
      end

      let(:category) { "education" }
      let(:hours) { nil }
      let(:credit_hours) { nil }

      context "when hours are reported" do
        let(:category) { "employment" }
        let(:hours) { 40 }

        it "returns the reported hours" do
          expect(activity.clock_hours).to eq(40)
        end
      end

      context "when an education activity reports credit hours instead of hours" do
        let(:credit_hours) { 9 }

        it "converts credit hours at 12.99 clock hours each" do
          expect(activity.clock_hours).to eq(9 * described_class::CREDIT_HOURS_MULTIPLIER)
        end
      end

      context "when an education activity reports both hours and credit hours" do
        let(:hours) { 25 }
        let(:credit_hours) { 9 }

        it "prefers the reported hours" do
          expect(activity.clock_hours).to eq(25)
        end
      end

      context "when a non-education activity reports credit hours without hours" do
        let(:category) { "employment" }
        let(:credit_hours) { 9 }

        it "returns nil rather than converting" do
          expect(activity.clock_hours).to be_nil
        end
      end

      context "when neither hours nor credit hours are reported" do
        it "returns nil" do
          expect(activity.clock_hours).to be_nil
        end
      end
    end
  end
end
