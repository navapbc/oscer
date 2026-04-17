# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExParteCommunityEngagementDeterminationService do
  describe ".determine" do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    def create_ex_parte_activity_for(certification, hours:)
      lookback = certification.certification_requirements.continuous_lookback_period
      create(:ex_parte_activity,
             member_id: certification.member_id,
             hours: hours,
             period_start: lookback.start.to_date,
             period_end: lookback.start.to_date.end_of_month)
    end

    def create_income_for(certification, gross_income:)
      lookback = certification.certification_requirements.continuous_lookback_period
      create(:income,
             member_id: certification.member_id,
             period_start: lookback.start.to_date,
             period_end: lookback.start.to_date.end_of_month,
             gross_income: gross_income)
    end

    context "when hours meet the CE threshold" do
      before { create_ex_parte_activity_for(certification, hours: 85) }

      it "delegates to HoursComplianceDeterminationService (DeterminedHoursMet path)" do
        allow(HoursComplianceDeterminationService).to receive(:determine).and_call_original
        allow(IncomeComplianceDeterminationService).to receive(:determine)

        described_class.determine(certification_case)

        expect(HoursComplianceDeterminationService).to have_received(:determine).with(certification_case)
        expect(IncomeComplianceDeterminationService).not_to have_received(:determine)
      end
    end

    context "when hours are below threshold" do
      before { create_ex_parte_activity_for(certification, hours: 50) }

      context "and income satisfies CE" do
        before { create_income_for(certification, gross_income: 620) }

        it "runs the income path only (DeterminedIncomeMet)" do
          allow(HoursComplianceDeterminationService).to receive(:determine)
          allow(IncomeComplianceDeterminationService).to receive(:determine).and_call_original

          described_class.determine(certification_case)

          expect(HoursComplianceDeterminationService).not_to have_received(:determine)
          expect(IncomeComplianceDeterminationService).to have_received(:determine).with(
            certification_case,
            hours_context: hash_including(:total_hours, :hours_by_source)
          )
          expect(Strata::EventManager).to have_received(:publish).with(
            "DeterminedIncomeMet",
            hash_including(
              case_id: certification_case.id,
              certification_id: certification.id,
              hours_data: hash_including(:total_hours)
            )
          )
        end
      end
    end
  end
end
