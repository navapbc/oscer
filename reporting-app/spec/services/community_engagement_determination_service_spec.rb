# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommunityEngagementDeterminationService do
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

  def hours_determination(certification_id)
    Determination.where(subject_id: certification_id).detect do |d|
      d.determination_data["calculation_type"] == Determination::CALCULATION_TYPE_HOURS_BASED
    end
  end

  def income_determination(certification_id)
    Determination.where(subject_id: certification_id).detect do |d|
      d.determination_data["calculation_type"] == Determination::CALCULATION_TYPE_INCOME_BASED
    end
  end

  describe ".determine" do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    context "when hours alone satisfy CE (OR)" do
      before { create_ex_parte_activity_for(certification, hours: 85) }

      it "publishes DeterminedCommunityEngagementMet with satisfied_by :hours" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          described_class::MET_EVENT,
          hash_including(
            case_id: certification_case.id,
            certification_id: certification.id,
            satisfied_by: :hours
          )
        )
      end
    end

    context "when income alone satisfies CE (OR)" do
      before { create_income_for(certification, gross_income: 620) }

      it "publishes DeterminedCommunityEngagementMet with satisfied_by :income" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          described_class::MET_EVENT,
          hash_including(
            case_id: certification_case.id,
            satisfied_by: :income
          )
        )
      end
    end

    context "when both hours and income meet targets" do
      before do
        create_ex_parte_activity_for(certification, hours: 85)
        create_income_for(certification, gross_income: 620)
      end

      it "publishes DeterminedCommunityEngagementMet with satisfied_by :both" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          described_class::MET_EVENT,
          hash_including(satisfied_by: :both)
        )
      end
    end

    context "when there is no ex parte hours and no ex parte income" do
      it "publishes DeterminedActionRequired" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          described_class::ACTION_REQUIRED_EVENT,
          hash_including(case_id: certification_case.id, certification_id: certification.id)
        )
      end
    end

    context "when only ex parte hours exist but below target" do
      before { create_ex_parte_activity_for(certification, hours: 50) }

      it "publishes DeterminedCommunityEngagementInsufficient with hours section only" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          described_class::INSUFFICIENT_EVENT,
          hash_including(
            show_hours_insufficient: true,
            show_income_insufficient: false,
            hours_data: hash_including(:total_hours),
            income_data: hash_including(:total_income)
          )
        )
      end
    end

    context "when only ex parte income exists but below target" do
      before { create_income_for(certification, gross_income: 400) }

      it "publishes DeterminedCommunityEngagementInsufficient with income section only" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          described_class::INSUFFICIENT_EVENT,
          hash_including(
            show_hours_insufficient: false,
            show_income_insufficient: true
          )
        )
      end
    end

    context "when both ex parte hours and income exist but both below targets" do
      before do
        create_ex_parte_activity_for(certification, hours: 50)
        create_income_for(certification, gross_income: 400)
      end

      it "publishes DeterminedCommunityEngagementInsufficient with both sections" do
        described_class.determine(certification_case)

        expect(Strata::EventManager).to have_received(:publish).with(
          described_class::INSUFFICIENT_EVENT,
          hash_including(
            show_hours_insufficient: true,
            show_income_insufficient: true
          )
        )
      end
    end
  end
end
