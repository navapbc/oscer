# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityReportStatisticsService do
  let(:member_id) { "MEMBER123" }
  let(:certification) do
    create(:certification,
           member_id: member_id,
           certification_requirements: build(:certification_certification_requirements,
                                              certification_date: Date.new(2025, 10, 15),
                                              months_that_can_be_certified: [ Date.new(2025, 10, 1), Date.new(2025, 9, 1) ]))
  end
  let(:certification_case) { create(:certification_case, certification: certification) }
  let(:activity_report) do
    ActivityReportApplicationForm.create!(
      user_id: create(:user).id,
      certification_case_id: certification_case.id,
      reporting_periods: [ { year: 2025, month: 10 } ]
    )
  end

  before do
    # Prevent auto-triggering business process during test setup
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(HoursComplianceDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  describe '.build_monthly_statistics' do
    context 'with only self-reported activities' do
      before do
        create(:work_activity,
               activity_report_application_form_id: activity_report.id,
               month: Date.new(2025, 10, 1),
               hours: 40,
               name: "Employer A")
        create(:work_activity,
               activity_report_application_form_id: activity_report.id,
               month: Date.new(2025, 10, 1),
               hours: 30,
               name: "Employer B")
      end

      it 'calculates total hours from self-reported activities' do
        stats = described_class.build_monthly_statistics(activity_report.reload, certification)

        october_stats = stats[Date.new(2025, 10, 1)]
        expect(october_stats[:summed_hours]).to eq(70.0)
        expect(october_stats[:hourly_activities].length).to eq(2)
        expect(october_stats[:ex_parte_activities]).to be_empty
      end

      it 'calculates remaining hours needed' do
        stats = described_class.build_monthly_statistics(activity_report.reload, certification)

        october_stats = stats[Date.new(2025, 10, 1)]
        expect(october_stats[:remaining_hours]).to eq(10.0) # 80 - 70 = 10
      end
    end

    context 'with only ex parte activities' do
      before do
        create(:ex_parte_activity,
               member_id: member_id,
               category: "employment",
               hours: 50,
               period_start: Date.new(2025, 10, 1),
               period_end: Date.new(2025, 10, 31))
      end

      it 'calculates total hours from ex parte activities' do
        stats = described_class.build_monthly_statistics(activity_report.reload, certification)

        october_stats = stats[Date.new(2025, 10, 1)]
        expect(october_stats[:summed_hours]).to eq(50.0)
        expect(october_stats[:ex_parte_activities].length).to eq(1)
        expect(october_stats[:hourly_activities]).to be_empty
      end

      it 'calculates remaining hours needed' do
        stats = described_class.build_monthly_statistics(activity_report.reload, certification)

        october_stats = stats[Date.new(2025, 10, 1)]
        expect(october_stats[:remaining_hours]).to eq(30.0) # 80 - 50 = 30
      end
    end

    context 'with both self-reported and ex parte activities' do
      before do
        create(:work_activity,
               activity_report_application_form_id: activity_report.id,
               month: Date.new(2025, 10, 1),
               hours: 30,
               name: "Self Employment")
        create(:ex_parte_activity,
               member_id: member_id,
               category: "employment",
               hours: 50,
               period_start: Date.new(2025, 10, 1),
               period_end: Date.new(2025, 10, 31))
      end

      it 'combines hours from both sources' do
        stats = described_class.build_monthly_statistics(activity_report.reload, certification)

        october_stats = stats[Date.new(2025, 10, 1)]
        expect(october_stats[:summed_hours]).to eq(80.0) # 30 + 50
        expect(october_stats[:hourly_activities].length).to eq(1)
        expect(october_stats[:ex_parte_activities].length).to eq(1)
      end

      it 'shows zero remaining hours when requirement is met' do
        stats = described_class.build_monthly_statistics(activity_report.reload, certification)

        october_stats = stats[Date.new(2025, 10, 1)]
        expect(october_stats[:remaining_hours]).to eq(0)
      end
    end

    context 'with ex parte activity spanning multiple months' do
      # Use a certification with a longer lookback period
      let(:certification) do
        create(:certification,
               member_id: member_id,
               certification_requirements: build(:certification_certification_requirements,
                                                  certification_date: Date.new(2025, 12, 15),
                                                  months_that_can_be_certified: [
                                                    Date.new(2025, 10, 1),
                                                    Date.new(2025, 11, 1),
                                                    Date.new(2025, 12, 1)
                                                  ]))
      end

      before do
        # Activity spans October and November (61 days total)
        create(:ex_parte_activity,
               member_id: member_id,
               category: "employment",
               hours: 61, # 1 hour per day for easy calculation
               period_start: Date.new(2025, 10, 1),
               period_end: Date.new(2025, 11, 30))
      end

      it 'allocates hours proportionally across months' do
        stats = described_class.build_monthly_statistics(activity_report.reload, certification)

        october_stats = stats[Date.new(2025, 10, 1)]
        november_stats = stats[Date.new(2025, 11, 1)]

        # October has 31 days, November has 30 days = 61 total days
        # October: 61 hours * (31/61) = 31 hours
        # November: 61 hours * (30/61) = 30 hours
        expect(october_stats[:ex_parte_activities].first[:allocated_hours]).to eq(31.0)
        expect(november_stats[:ex_parte_activities].first[:allocated_hours]).to eq(30.0)
      end
    end

    context 'with income activities' do
      before do
        create(:income_activity,
               activity_report_application_form_id: activity_report.id,
               month: Date.new(2025, 10, 1),
               income: 60000) # $600 in cents
      end

      it 'calculates income separately from hours' do
        stats = described_class.build_monthly_statistics(activity_report.reload, certification)

        october_stats = stats[Date.new(2025, 10, 1)]
        expect(october_stats[:summed_income]).to eq(600)
        expect(october_stats[:income_activities].length).to eq(1)
        expect(october_stats[:remaining_income]).to eq(0) # 580 minimum met
      end
    end

    context 'with no activities' do
      it 'returns empty statistics' do
        stats = described_class.build_monthly_statistics(activity_report.reload, certification)

        expect(stats).to be_empty
      end
    end

    context 'when certification is nil' do
      it 'returns statistics with only self-reported activities' do
        create(:work_activity,
               activity_report_application_form_id: activity_report.id,
               month: Date.new(2025, 10, 1),
               hours: 40,
               name: "Test")

        stats = described_class.build_monthly_statistics(activity_report.reload, nil)

        october_stats = stats[Date.new(2025, 10, 1)]
        expect(october_stats[:summed_hours]).to eq(40.0)
        expect(october_stats[:ex_parte_activities]).to be_empty
      end
    end
  end

  describe '.fetch_ex_parte_activities' do
    context 'with activities within lookback period' do
      before do
        create(:ex_parte_activity,
               member_id: member_id,
               category: "employment",
               hours: 40,
               period_start: Date.new(2025, 10, 1),
               period_end: Date.new(2025, 10, 15))
      end

      it 'returns activities for the member' do
        activities = described_class.fetch_ex_parte_activities(certification)

        expect(activities.count).to eq(1)
        expect(activities.first.member_id).to eq(member_id)
      end
    end

    context 'with activities outside lookback period' do
      before do
        create(:ex_parte_activity,
               member_id: member_id,
               category: "employment",
               hours: 40,
               period_start: Date.new(2024, 1, 1),
               period_end: Date.new(2024, 1, 31))
      end

      it 'does not return activities outside the period' do
        activities = described_class.fetch_ex_parte_activities(certification)

        expect(activities.count).to eq(0)
      end
    end

    context 'when certification is nil' do
      it 'returns empty relation' do
        activities = described_class.fetch_ex_parte_activities(nil)

        expect(activities).to be_empty
      end
    end

    context 'when certification has no member_id' do
      let(:certification_without_member) { build(:certification, member_id: nil) }

      it 'returns empty relation' do
        activities = described_class.fetch_ex_parte_activities(certification_without_member)

        expect(activities).to be_empty
      end
    end
  end
end
