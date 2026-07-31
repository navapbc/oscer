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

  def create_external_hourly_activity_for(certification, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback.start.to_date
    period_end = lookback.start.to_date.end_of_month

    create(:external_hourly_activity, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, **attrs)
  end

  def create_income_for(certification, gross_income:, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback.start.to_date
    period_end = lookback.start.to_date.end_of_month

    create(:external_income_activity, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, gross_income: gross_income, **attrs)
  end

  # .assess is the derivation .determine used to inline. It is public so a second step can reuse it
  # rather than re-deriving the same four values and risking a different verdict.
  describe ".assess" do
    let(:over_hours) { HoursComplianceDeterminationService::TARGET_HOURS + 5 }
    let(:under_hours) { HoursComplianceDeterminationService::TARGET_HOURS / 2 }
    let(:over_income) { IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY + 20 }
    let(:under_income) { IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY / 2 }

    it "returns both aggregates and their per-track verdicts when only hours pass" do
      create_external_hourly_activity_for(certification, hours: over_hours)

      assessment = described_class.assess(certification)

      expect(assessment.hours_data[:total_hours]).to eq(over_hours)
      expect(assessment.income_data[:total_income]).to be_zero
      expect(assessment.hours_ok).to be(true)
      expect(assessment.income_ok).to be(false)
      expect(assessment.met?).to be(true)
    end

    # met? is hours_ok || income_ok; without this the income side is never exercised.
    it "reports met? when only the income track passes" do
      create_external_hourly_activity_for(certification, hours: under_hours)
      create_income_for(certification, gross_income: over_income)

      assessment = described_class.assess(certification)

      expect(assessment.income_data[:total_income]).to eq(over_income)
      expect(assessment.hours_ok).to be(false)
      expect(assessment.income_ok).to be(true)
      expect(assessment.met?).to be(true)
    end

    # Both tracks carry below-threshold data, so a verdict derived from presence rather than amount
    # fails here instead of passing on an empty aggregate.
    it "reports met? false when neither track passes" do
      create_external_hourly_activity_for(certification, hours: under_hours)
      create_income_for(certification, gross_income: under_income)

      assessment = described_class.assess(certification)

      expect(assessment.hours_data[:total_hours]).to be_positive
      expect(assessment.income_data[:total_income]).to be_positive
      expect(assessment.hours_ok).to be(false)
      expect(assessment.income_ok).to be(false)
      expect(assessment.met?).to be(false)
    end
  end

  describe ".determine" do
    context "when hours meet target (hours-only pass)" do
      before do
        create_external_hourly_activity_for(certification, hours: 85)
      end

      it "aggregates income scoped to the case under assessment" do
        allow(IncomeComplianceDeterminationService).to receive(:aggregate_income_for_certification).and_call_original

        described_class.determine(certification_case)

        expect(IncomeComplianceDeterminationService).to have_received(:aggregate_income_for_certification)
          .with(certification)
      end

      it "records combined determination with hours satisfied and income assessed" do
        described_class.determine(certification_case)

        determination = latest_determination_for(certification.id)
        expect(determination.outcome).to eq("compliant")
        expect(determination.reasons).to eq([ "hours_reported_compliant" ])
        data = determination.determination_data
        expect(data["calculation_type"]).to eq(Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED)
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

      it 'logs approved event' do
        expect do
          described_class.determine(certification_case)
        end.to change { Strata::AuditLine.where(subject: certification, actor_type: described_class.name, action: 'case.activity_report.approved').count }.by(1)
      end
    end

    context "when hours are below target but income meets threshold (income-only pass)" do
      before do
        create_external_hourly_activity_for(certification, hours: 40)
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

      it 'logs approved event' do
        expect do
          described_class.determine(certification_case)
        end.to change { Strata::AuditLine.where(subject: certification, actor_type: described_class.name, action: 'case.activity_report.approved').count }.by(1)
      end
    end

    context "when both hours and income meet targets" do
      before do
        create_external_hourly_activity_for(certification, hours: 90)
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

    # Not-met defers to the trailing step (OSCER-805), which owns the negative determination and
    # the Insufficient/ActionRequired split, so this service records nothing here.
    context "when neither hours nor income meet targets with some external hours" do
      before do
        create_external_hourly_activity_for(certification, hours: 40)
        create_income_for(certification, gross_income: 400)
      end

      it "records no determination, deferring the negative to the data-source step" do
        expect do
          described_class.determine(certification_case)
        end.not_to change { Determination.unscope(:order).where(subject_id: certification.id).count }
      end

      it "publishes DeterminedCommunityEngagementNotMet to route into the data-source step" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementNotMet",
          hash_including(case_id: certification_case.id)
        )
      end

      # The member-facing negative events publish from the trailing step instead.
      # NotificationsEventListener binds handlers to event NAMES with no step
      # awareness, so publishing either one here would email the member before the
      # data sources have been consulted.
      it "publishes neither member-facing negative event" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).not_to have_received(:publish).with(
          "DeterminedCommunityEngagementInsufficient", anything
        )
        expect(Strata::EventManager).not_to have_received(:publish).with(
          "DeterminedCommunityEngagementActionRequired", anything
        )
      end

      it 'does not log the denied event (the data-source step does)' do
        expect do
          described_class.determine(certification_case)
        end.not_to change { Strata::AuditLine.where(subject: certification, actor_type: described_class.name, action: 'case.activity_report.denied').count }
      end
    end

    context "when neither track passes and there are no external hours" do
      before do
        create_income_for(certification, gross_income: 100)
      end

      it "records no determination" do
        expect do
          described_class.determine(certification_case)
        end.not_to change { Determination.unscope(:order).where(subject_id: certification.id).count }
      end

      # The external-hours branching that chose Insufficient vs ActionRequired moves
      # to the trailing step, so both not-met flavors leave here as the same event.
      it "publishes DeterminedCommunityEngagementNotMet" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedCommunityEngagementNotMet",
          hash_including(case_id: certification_case.id)
        )
      end
    end

    context "when total hours exactly equal TARGET_HOURS" do
      before do
        create_external_hourly_activity_for(certification, hours: HoursComplianceDeterminationService::TARGET_HOURS)
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
        create_external_hourly_activity_for(certification, hours: 40)
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
