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

    describe "enrollment_status validation" do
      subject(:activity) do
        described_class.new(
          type: type,
          category: category,
          hours: hours,
          enrollment_status: enrollment_status,
          period_start: Date.new(2025, 12, 1),
          period_end: Date.new(2025, 12, 31),
          verification_status: "verified"
        )
      end

      let(:type) { "hourly" }
      let(:category) { "education" }
      let(:hours) { 40 }
      let(:enrollment_status) { "full_time" }

      it "is valid for each enrollment status" do
        described_class::ENROLLMENT_STATUSES.each do |status|
          expect(described_class.new(
            type:, category:, hours:, enrollment_status: status,
            period_start: Date.new(2025, 12, 1), period_end: Date.new(2025, 12, 31),
            verification_status: "verified"
          )).to be_valid
        end
      end

      context "when the status is not a recognized enrollment status" do
        let(:enrollment_status) { "part_time" }

        it "is invalid" do
          expect(activity).not_to be_valid
          expect(activity.errors).to be_of_kind(:enrollment_status, :inclusion)
        end
      end

      context "when the activity is not an education activity" do
        let(:category) { "employment" }

        it "is invalid" do
          expect(activity).not_to be_valid
          expect(activity.errors).to be_of_kind(:enrollment_status, :present)
        end
      end

      context "when the activity is an income activity" do
        let(:type) { "income" }
        let(:hours) { nil }

        it "is invalid" do
          expect(activity).not_to be_valid
          expect(activity.errors).to be_of_kind(:enrollment_status, :present)
        end
      end

      context "when an enrolled education activity reports neither hours nor credit hours" do
        let(:hours) { nil }

        it "is valid" do
          expect(activity).to be_valid
        end
      end

      # Accepted and contributes nothing, rather than rejected for the missing hours.
      context "when a below-half-time education activity reports neither hours nor credit hours" do
        let(:hours) { nil }
        let(:enrollment_status) { "less_than_half_time" }

        it "is valid" do
          expect(activity).to be_valid
        end
      end

      context "when an education activity reports no hours, credit hours, or enrollment status" do
        let(:hours) { nil }
        let(:enrollment_status) { nil }

        it "is invalid" do
          expect(activity).not_to be_valid
          expect(activity.errors).to be_of_kind(:hours, :blank)
        end
      end
    end

    describe "#qualifying_enrollment?" do
      subject(:activity) do
        described_class.new(type: "hourly", category: "education", enrollment_status: enrollment_status)
      end

      %w[full_time half_time].each do |status|
        context "when enrolled #{status}" do
          let(:enrollment_status) { status }

          it "qualifies" do
            expect(activity.qualifying_enrollment?).to be(true)
          end
        end
      end

      context "when enrolled less than half time" do
        let(:enrollment_status) { "less_than_half_time" }

        it "does not qualify" do
          expect(activity.qualifying_enrollment?).to be(false)
        end
      end

      context "when no enrollment status is reported" do
        let(:enrollment_status) { nil }

        it "does not qualify" do
          expect(activity.qualifying_enrollment?).to be(false)
        end
      end
    end
  end
end
