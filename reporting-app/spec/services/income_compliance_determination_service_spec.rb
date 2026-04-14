# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncomeComplianceDeterminationService do
  def expect_no_ce_workflow_events_published
    expect(Strata::EventManager).not_to have_received(:publish).with("DeterminedHoursMet", anything)
    expect(Strata::EventManager).not_to have_received(:publish).with("DeterminedHoursInsufficient", anything)
    expect(Strata::EventManager).not_to have_received(:publish).with("DeterminedActionRequired", anything)
  end

  # Income rows aligned with the certification's continuous lookback (parity with hours ex parte helper).
  def create_income_for(certification, gross_income:, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback.start.to_date
    period_end = lookback.start.to_date.end_of_month

    create(:income, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, gross_income: gross_income, **attrs)
  end

  describe "TARGET_INCOME_MONTHLY" do
    it "defaults to 580" do
      expect(described_class::TARGET_INCOME_MONTHLY).to eq(BigDecimal("580"))
    end
  end

  describe ".determine" do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    context "when income meets target" do
      before do
        create_income_for(certification, gross_income: 620)
      end

      it "publishes DeterminedHoursMet event" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedHoursMet",
          hash_including(case_id: certification_case.id)
        )
      end

      it "creates a compliant determination with income reason code" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to include("income_reported_compliant")
      end

      it "closes the case" do
        described_class.determine(certification_case)

        expect(certification_case.reload).to be_closed
      end

      it "stores income_based determination_data" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        data = determination.determination_data

        expect(data["calculation_type"]).to eq(Determination::CALCULATION_TYPE_INCOME_BASED)
        expect(data["total_income"]).to eq(620.0)
        expect(data["target_income"]).to eq(580.0)
        expect(data["calculation_method"]).to eq(Determination::CALCULATION_METHOD_AUTOMATED_INCOME_INTAKE)
        expect(data["income_by_source"]).to eq("income" => 620.0, "activity" => 0.0)
      end
    end

    context "when income is below target with some ex parte income" do
      before do
        create_income_for(certification, gross_income: 400)
      end

      it "publishes DeterminedHoursInsufficient with income_data" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedHoursInsufficient",
          hash_including(
            case_id: certification_case.id,
            income_data: hash_including(:total_income)
          )
        )
      end

      it "creates a not_compliant determination" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("income_reported_insufficient")
      end

      it "does not close the case" do
        described_class.determine(certification_case)

        expect(certification_case.reload).not_to be_closed
      end
    end

    context "when income is below target with NO income rows" do
      it "publishes DeterminedActionRequired" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedActionRequired",
          hash_including(case_id: certification_case.id)
        )
      end

      it "creates a not_compliant determination" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("income_reported_insufficient")
      end
    end

    context "when total income exactly meets target" do
      before do
        create_income_for(certification, gross_income: 580)
      end

      it "is compliant" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("compliant")
      end
    end
  end

  describe ".calculate" do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
      create(:certification_case, certification: certification)
    end

    let(:certification) { create(:certification) }

    context "when income meets target" do
      before do
        create_income_for(certification, gross_income: 600)
      end

      it "creates a compliant automated determination (no workflow events from this method)" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to include("income_reported_compliant")
        expect(determination.decision_method).to eq("automated")
        expect_no_ce_workflow_events_published
      end
    end

    context "when income is below target" do
      before do
        create_income_for(certification, gross_income: 100)
      end

      it "creates a not_compliant determination" do
        described_class.calculate(certification.id)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to include("income_reported_insufficient")
        expect_no_ce_workflow_events_published
      end
    end
  end

  describe "income aggregation" do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    context "with multiple Income rows in lookback" do
      before do
        create_income_for(certification, gross_income: 300.0, category: "employment")
        create_income_for(certification, gross_income: 280.25, category: "education")
      end

      it "sums gross_income across rows" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["total_income"]).to eq(580.25)
      end

      it "includes income_ids" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.determination_data["income_ids"].length).to eq(2)
      end
    end

    context "with income outside lookback period" do
      before do
        create_income_for(certification, gross_income: 300)

        create(:income,
               member_id: certification.member_id,
               gross_income: 10_000,
               period_start: 2.years.ago.to_date,
               period_end: 2.years.ago.to_date.end_of_month)
      end

      it "only counts income within the lookback period" do
        described_class.determine(certification_case)

        determination = Determination.where(subject_id: certification.id).last
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.determination_data["total_income"]).to eq(300.0)
      end
    end
  end

  describe ".aggregate_income_for_certification" do
    before do
      allow(Strata::EventManager).to receive(:publish)
    end

    let(:certification) { create(:certification) }

    it "exposes member_reported_income_total as zero until modeled (stub)" do
      create_income_for(certification, gross_income: 100)
      agg = described_class.aggregate_income_for_certification(certification)

      expect(agg[:income_by_source][:activity]).to eq(BigDecimal("0"))
      expect(agg[:total_income]).to eq(BigDecimal("100"))
      expect_no_ce_workflow_events_published
    end
  end
end
