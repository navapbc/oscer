# frozen_string_literal: true

require "rails_helper"

RSpec.describe HoursComplianceDeterminationService do
  # Helper to create ex_parte_activity with periods matching the certification's lookback
  def create_ex_parte_activity_for(certification, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback.start.to_date
    period_end = lookback.start.to_date.end_of_month

    create(:ex_parte_activity, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, **attrs)
  end

  describe ".determine" do
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification_id: certification.id) }

    context "when hours meet target" do
      before do
        create_ex_parte_activity_for(certification, hours: 85)
        allow(Strata::EventManager).to receive(:publish)
      end

      it "publishes DeterminedRequirementsMet event" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedRequirementsMet",
          { case_id: certification_case.id }
        )
      end

      it "creates a compliant determination" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to include("hours_reported_compliant")
      end

      it "closes the case" do
        described_class.determine(certification_case)

        expect(certification_case.reload).to be_closed
      end

      it "sets activity_report_approval_status to approved" do
        described_class.determine(certification_case)

        expect(certification_case.reload.activity_report_approval_status).to eq("approved")
      end

      it "includes determination_data with calculation details" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        data = determination.determination_data

        expect(data["calculation_type"]).to eq("hours_based")
        expect(data["calculation_method"]).to eq("business_process")
        expect(data["total_hours"]).to eq(85.0)
        expect(data["target_hours"]).to eq(80)
      end
    end

    context "when hours are below target" do
      before do
        create_ex_parte_activity_for(certification, hours: 50)
        allow(Strata::EventManager).to receive(:publish)
      end

      it "publishes DeterminedRequirementsNotMet event" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedRequirementsNotMet",
          { case_id: certification_case.id }
        )
      end

      it "does not create a determination" do
        expect {
          described_class.determine(certification_case)
        }.not_to change { Determination.where(subject_id: certification.id).count }
      end

      it "does not close the case" do
        described_class.determine(certification_case)

        expect(certification_case.reload).not_to be_closed
      end
    end

    context "when hours exactly meet target" do
      before do
        create_ex_parte_activity_for(certification, hours: 80)
      end

      it "is compliant" do
        allow(Strata::EventManager).to receive(:publish)

        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedRequirementsMet",
          { case_id: certification_case.id }
        )
      end
    end

    context "with no hours data" do
      before do
        allow(Strata::EventManager).to receive(:publish)
      end

      it "publishes DeterminedRequirementsNotMet event" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedRequirementsNotMet",
          { case_id: certification_case.id }
        )
      end
    end
  end

  describe ".calculate" do
    let(:certification) { create(:certification) }

    context "when hours meet target" do
      before do
        create_ex_parte_activity_for(certification, hours: 90)
      end

      it "creates a compliant determination" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to include("hours_reported_compliant")
        expect(determination.decision_method).to eq("automated")
      end

      it "includes determination_data with async calculation_method" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        data = determination.determination_data

        expect(data["calculation_type"]).to eq("hours_based")
        expect(data["calculation_method"]).to eq("async_recalculation")
        expect(data["total_hours"]).to eq(90.0)
        expect(data["target_hours"]).to eq(80)
      end
    end

    context "when hours are below target" do
      before do
        create_ex_parte_activity_for(certification, hours: 40)
      end

      it "creates a not_compliant determination" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("hours_reported_insufficient")
      end
    end
  end

  describe "hours aggregation" do
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification_id: certification.id) }

    context "with multiple ex_parte activities" do
      before do
        create_ex_parte_activity_for(certification, category: "employment", hours: 40)
        create_ex_parte_activity_for(certification, category: "community_service", hours: 30)
        create_ex_parte_activity_for(certification, category: "education", hours: 15)
      end

      it "sums hours across all entries" do
        allow(Strata::EventManager).to receive(:publish)

        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["total_hours"]).to eq(85.0)
      end

      it "groups hours by category" do
        allow(Strata::EventManager).to receive(:publish)

        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        by_category = determination.determination_data["hours_by_category"]

        expect(by_category["employment"]).to eq(40.0)
        expect(by_category["community_service"]).to eq(30.0)
        expect(by_category["education"]).to eq(15.0)
      end

      it "tracks hours by source" do
        allow(Strata::EventManager).to receive(:publish)

        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        by_source = determination.determination_data["hours_by_source"]

        expect(by_source["ex_parte"]).to eq(85.0)
        expect(by_source["activity"]).to eq(0.0)
      end

      it "includes entry IDs in determination_data" do
        allow(Strata::EventManager).to receive(:publish)

        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["ex_parte_activity_ids"].length).to eq(3)
      end
    end

    context "with activities outside lookback period" do
      before do
        # Create activity within lookback period
        create_ex_parte_activity_for(certification, hours: 50)

        # Create activity outside lookback period (far in the past)
        create(:ex_parte_activity,
               member_id: certification.member_id,
               hours: 100,
               period_start: 2.years.ago.to_date,
               period_end: 2.years.ago.to_date.end_of_month)
      end

      it "only counts hours within the lookback period" do
        allow(Strata::EventManager).to receive(:publish)

        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        # Should only count 50 hours (within period), not 150 (50 + 100)
        expect(determination).to be_nil # 50 hours < 80 target = not compliant, no determination
      end
    end
  end

  describe "TARGET_HOURS" do
    it "defaults to 80" do
      expect(described_class::TARGET_HOURS).to eq(80)
    end
  end
end
