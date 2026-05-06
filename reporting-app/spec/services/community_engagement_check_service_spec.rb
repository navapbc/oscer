# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommunityEngagementCheckService do
  before do
    allow(Strata::EventManager).to receive(:publish)
    allow(NotificationService).to receive(:send_email_notification)
    allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_call_original
    allow(IncomeComplianceDeterminationService).to receive(:aggregate_income_for_certification).and_call_original
  end

  let(:certification) { create(:certification) }
  let(:certification_case) { create(:certification_case, certification: certification) }

  def create_ex_parte_activity_for(certification, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback.start.to_date
    period_end = lookback.start.to_date.end_of_month

    create(:ex_parte_activity, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, **attrs)
  end

  def create_income_for(certification, gross_income:, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback.start.to_date
    period_end = lookback.start.to_date.end_of_month

    create(:income, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, gross_income: gross_income, **attrs)
  end

  def latest_determination_for(certification_id)
    Determination.unscope(:order).where(subject_id: certification_id).order(created_at: :desc).first
  end

  describe ".determine" do
    context "when hours meet target (hours-only pass)" do
      before do
        create_ex_parte_activity_for(certification, hours: 85)
      end

      it "records combined determination with hours satisfied and income assessed" do
        described_class.determine(certification_case)

        determination = latest_determination_for(certification.id)
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to eq([ "hours_reported_compliant" ])
        data = determination.determination_data
        expect(data["calculation_type"]).to eq(Determination::CALCULATION_TYPE_EX_PARTE_CE_COMBINED)
        expect(data["satisfied_by"]).to eq(Determination::SATISFIED_BY_HOURS)
        expect(data["hours"]["compliant"]).to be true
        expect(data["income"]["compliant"]).to be false
      end

      it "publishes DeterminedCommunityEngagementMet" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementMet",
          hash_including(case_id: certification_case.id)
        )
      end
    end

    context "when hours are below target but income meets threshold (income-only pass)" do
      before do
        create_ex_parte_activity_for(certification, hours: 40)
        create_income_for(certification, gross_income: 600)
      end

      it "records combined determination with income satisfied" do
        described_class.determine(certification_case)

        determination = latest_determination_for(certification.id)
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to eq([ "income_reported_compliant" ])
        data = determination.determination_data
        expect(data["satisfied_by"]).to eq(Determination::SATISFIED_BY_INCOME)
        expect(data["hours"]["compliant"]).to be false
        expect(data["income"]["compliant"]).to be true
      end

      it "publishes DeterminedCommunityEngagementMet" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementMet",
          hash_including(case_id: certification_case.id)
        )
      end
    end

    context "when both hours and income meet targets" do
      before do
        create_ex_parte_activity_for(certification, hours: 90)
        create_income_for(certification, gross_income: 700)
      end

      it "records both compliant reason codes and satisfied_by both" do
        described_class.determine(certification_case)

        determination = latest_determination_for(certification.id)
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to contain_exactly("hours_reported_compliant", "income_reported_compliant")
        expect(determination.determination_data["satisfied_by"]).to eq(Determination::SATISFIED_BY_BOTH)
        expect(determination.determination_data["hours"]["compliant"]).to be true
        expect(determination.determination_data["income"]["compliant"]).to be true
      end

      it "publishes DeterminedCommunityEngagementMet" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementMet",
          hash_including(case_id: certification_case.id)
        )
      end
    end

    context "when neither hours nor income meet targets with some ex parte hours" do
      before do
        create_ex_parte_activity_for(certification, hours: 40)
        create_income_for(certification, gross_income: 400)
      end

      it "records not_compliant with both insufficient reason codes when some ex parte hours are present" do
        described_class.determine(certification_case)

        determination = latest_determination_for(certification.id)
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to contain_exactly(
          "hours_reported_insufficient",
          "income_reported_insufficient"
        )
        data = determination.determination_data
        expect(data["calculation_type"]).to eq(Determination::CALCULATION_TYPE_EX_PARTE_CE_COMBINED)
        expect(data["satisfied_by"]).to eq(Determination::SATISFIED_BY_NEITHER)
        expect(data["hours"]["compliant"]).to be false
        expect(data["income"]["compliant"]).to be false
      end

      it "publishes DeterminedCommunityEngagementInsufficient with hours and income payload" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementInsufficient",
          hash_including(
            case_id: certification_case.id,
            hours_data: kind_of(Hash),
            income_data: kind_of(Hash)
          )
        )
      end
    end

    context "when neither track passes and there are no ex parte hours" do
      before do
        create_income_for(certification, gross_income: 100)
      end

      it "records not_compliant with both insufficient reason codes when there are no ex parte hours" do
        described_class.determine(certification_case)

        determination = latest_determination_for(certification.id)
        expect(determination.outcome).to eq("not_compliant")
        expect(determination.reasons).to contain_exactly(
          "hours_reported_insufficient",
          "income_reported_insufficient"
        )
        data = determination.determination_data
        expect(data["calculation_type"]).to eq(Determination::CALCULATION_TYPE_EX_PARTE_CE_COMBINED)
        expect(data["satisfied_by"]).to eq(Determination::SATISFIED_BY_NEITHER)
        expect(data["hours"]["compliant"]).to be false
        expect(data["income"]["compliant"]).to be false
      end

      it "publishes DeterminedCommunityEngagementActionRequired" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementActionRequired",
          hash_including(case_id: certification_case.id)
        )
      end
    end

    context "when total hours exactly equal TARGET_HOURS" do
      before do
        create_ex_parte_activity_for(certification, hours: HoursComplianceDeterminationService::TARGET_HOURS)
      end

      it "treats hours as compliant (inclusive threshold)" do
        described_class.determine(certification_case)

        determination = latest_determination_for(certification.id)
        expect(determination.outcome).to eq("compliant")
        expect(determination.determination_data["hours"]["compliant"]).to be true
      end
    end

    context "when total income exactly equals TARGET_INCOME_MONTHLY and hours are below target" do
      before do
        create_ex_parte_activity_for(certification, hours: 40)
        create_income_for(certification, gross_income: IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY)
      end

      it "treats income as compliant (inclusive threshold)" do
        described_class.determine(certification_case)

        determination = latest_determination_for(certification.id)
        expect(determination.outcome).to eq("compliant")
        expect(determination.determination_data["income"]["compliant"]).to be true
      end
    end
  end
end
