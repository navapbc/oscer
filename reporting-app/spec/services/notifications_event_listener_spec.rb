# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationsEventListener, type: :service do
  let(:region) { "Southeast" }
  let(:certification) do
    create(
      :certification,
      certification_requirements: build(:certification_certification_requirements, region: region)
    )
  end
  let(:certification_case) { CertificationCase.find_by(certification_id: certification.id) }

  before do
    allow(NotificationService).to receive(:send_email_notification)
    # Stub services that may publish events during certification creation
    allow(HoursComplianceDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
  end

  describe ".subscribe" do
    it "subscribes to all notification events" do
      allow(Strata::EventManager).to receive(:subscribe)

      described_class.subscribe

      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedExempt", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedHoursMet", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedCommunityEngagementMet", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedActionRequired", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedCommunityEngagementActionRequired", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedHoursInsufficient", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedCommunityEngagementInsufficient", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("ActivityReportApproved", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("ActivityReportDenied", anything)
    end
  end

  describe "event handlers" do
    # Test the handler methods directly rather than through event subscriptions
    # to avoid issues with multiple subscriptions across tests

    describe "#handle_exempt" do
      it "sends exempt_email notification" do
        event = { payload: { case_id: certification_case.id, certification_id: certification.id } }

        described_class.send(:handle_exempt, event)

        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          { certification: certification },
          :exempt_email,
          [ certification.member_email ]
        )
      end
    end

    describe "#handle_compliant" do
      it "sends compliant_email notification" do
        event = {
          payload: {
            case_id: certification_case.id,
            certification_id: certification.id
          }
        }

        described_class.send(:handle_compliant, event)

        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          { certification: certification },
          :compliant_email,
          [ certification.member_email ]
        )
      end
    end

    describe "#handle_action_required" do
      it "sends action_required_email notification" do
        event = {
          payload: {
            case_id: certification_case.id,
            certification_id: certification.id
          }
        }

        described_class.send(:handle_action_required, event)

        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          { certification: certification },
          :action_required_email,
          [ certification.member_email ]
        )
      end
    end

    describe "#handle_insufficient_hours" do
      it "sends insufficient_hours_email notification with hours data" do
        allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification)
          .with(certification)
          .and_return({ total_hours: 40, hours_by_source: { ex_parte: 40, activity: 0 } })

        event = {
          payload: {
            case_id: certification_case.id,
            certification_id: certification.id
          }
        }

        described_class.send(:handle_insufficient_hours, event)

        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          {
            certification: certification,
            hours_data: { total_hours: 40, hours_by_source: { ex_parte: 40, activity: 0 } },
            target_hours: HoursComplianceDeterminationService::TARGET_HOURS
          },
          :insufficient_hours_email,
          [ certification.member_email ]
        )
      end
    end

    describe "#handle_insufficient_community_engagement" do
      it "derives mailer flags for IncomeComplianceDeterminationService payload (income_data only, no show_* keys)" do
        allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification)
        allow(IncomeComplianceDeterminationService).to receive(:aggregate_income_for_certification)

        income_data = {
          total_income: BigDecimal("400"),
          income_by_source: { income: BigDecimal("400"), activity: BigDecimal("0") },
          income_ids: [],
          period_start: Date.current,
          period_end: Date.current
        }

        event = {
          payload: {
            case_id: certification_case.id,
            certification_id: certification.id,
            income_data: income_data
          }
        }

        described_class.send(:handle_insufficient_community_engagement, event)

        expect(HoursComplianceDeterminationService).not_to have_received(:aggregate_hours_for_certification)
        expect(IncomeComplianceDeterminationService).not_to have_received(:aggregate_income_for_certification)
        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          {
            certification: certification,
            income_data: income_data,
            hours_data: nil,
            target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
            target_income: IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY,
            show_hours_insufficient: false,
            show_income_insufficient: true
          },
          :insufficient_community_engagement_email,
          [ certification.member_email ]
        )
      end

      it "sends insufficient_community_engagement_email with payload data (no extra aggregate)" do
        allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification)
        allow(IncomeComplianceDeterminationService).to receive(:aggregate_income_for_certification)

        income_data = {
          total_income: BigDecimal("400"),
          income_by_source: { income: BigDecimal("400"), activity: BigDecimal("0") },
          income_ids: [],
          period_start: Date.current,
          period_end: Date.current
        }

        event = {
          payload: {
            case_id: certification_case.id,
            certification_id: certification.id,
            income_data: income_data,
            show_hours_insufficient: false,
            show_income_insufficient: true
          }
        }

        described_class.send(:handle_insufficient_community_engagement, event)

        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          {
            certification: certification,
            income_data: income_data,
            hours_data: nil,
            target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
            target_income: IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY,
            show_hours_insufficient: false,
            show_income_insufficient: true
          },
          :insufficient_community_engagement_email,
          [ certification.member_email ]
        )
        expect(HoursComplianceDeterminationService).not_to have_received(:aggregate_hours_for_certification)
        expect(IncomeComplianceDeterminationService).not_to have_received(:aggregate_income_for_certification)
      end

      it "aggregates hours when show_hours_insufficient is true and hours_data is omitted" do
        aggregated_hours = {
          total_hours: 50.0,
          hours_by_category: {},
          hours_by_source: { ex_parte: 50, activity: 0 },
          ex_parte_activity_ids: [],
          activity_ids: []
        }
        income_data = {
          total_income: BigDecimal("0"),
          income_by_source: { income: BigDecimal("0"), activity: BigDecimal("0") },
          income_ids: [],
          period_start: Date.current,
          period_end: Date.current
        }

        allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification)
          .with(certification)
          .and_return(aggregated_hours)
        allow(IncomeComplianceDeterminationService).to receive(:aggregate_income_for_certification)

        event = {
          payload: {
            case_id: certification_case.id,
            certification_id: certification.id,
            income_data: income_data,
            show_hours_insufficient: true,
            show_income_insufficient: false
          }
        }

        described_class.send(:handle_insufficient_community_engagement, event)

        expect(HoursComplianceDeterminationService).to have_received(:aggregate_hours_for_certification).with(certification)
        expect(IncomeComplianceDeterminationService).not_to have_received(:aggregate_income_for_certification)
        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          {
            certification: certification,
            hours_data: aggregated_hours,
            income_data: income_data,
            target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
            target_income: IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY,
            show_hours_insufficient: true,
            show_income_insufficient: false
          },
          :insufficient_community_engagement_email,
          [ certification.member_email ]
        )
      end
    end

    describe "#handle_activity_report_approved" do
      it "sends compliant_email notification" do
        event = { payload: { case_id: certification_case.id, certification_id: certification.id } }

        described_class.send(:handle_activity_report_approved, event)

        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          { certification: certification },
          :compliant_email,
          [ certification.member_email ]
        )
      end
    end

    describe "#handle_activity_report_denied" do
      it "sends insufficient_hours_email notification" do
        allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification)
          .with(certification)
          .and_return({ total_hours: 30, hours_by_source: { ex_parte: 30, activity: 0 } })

        event = { payload: { case_id: certification_case.id, certification_id: certification.id } }

        described_class.send(:handle_activity_report_denied, event)

        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          {
            certification: certification,
            hours_data: { total_hours: 30, hours_by_source: { ex_parte: 30, activity: 0 } },
            target_hours: HoursComplianceDeterminationService::TARGET_HOURS
          },
          :insufficient_hours_email,
          [ certification.member_email ]
        )
      end
    end
  end
end
