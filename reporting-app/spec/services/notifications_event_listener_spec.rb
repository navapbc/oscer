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
    allow(CommunityEngagementDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
  end

  describe ".subscribe" do
    it "subscribes to all notification events" do
      allow(Strata::EventManager).to receive(:subscribe)

      described_class.subscribe

      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedExempt", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedCommunityEngagementMet", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedHoursMet", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedActionRequired", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedCommunityEngagementInsufficient", anything)
      expect(Strata::EventManager).to have_received(:subscribe).with("DeterminedHoursInsufficient", anything)
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

    describe "#handle_community_engagement_met" do
      it "sends compliant_email with ce_satisfied_by" do
        event = {
          payload: {
            case_id: certification_case.id,
            certification_id: certification.id,
            satisfied_by: :income
          }
        }

        described_class.send(:handle_community_engagement_met, event)

        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          {
            certification: certification,
            ce_satisfied_by: :income
          },
          :compliant_email,
          [ certification.member_email ]
        )
      end
    end

    describe "#handle_community_engagement_insufficient" do
      it "sends community_engagement_insufficient_email with section flags and data" do
        hours_data = { total_hours: 50, hours_by_source: { ex_parte: 50, activity: 0 } }
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
            hours_data: hours_data,
            income_data: income_data,
            show_hours_insufficient: true,
            show_income_insufficient: true
          }
        }

        described_class.send(:handle_community_engagement_insufficient, event)

        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          {
            certification: certification,
            hours_data: hours_data,
            income_data: income_data,
            show_hours: true,
            show_income: true,
            target_hours: HoursComplianceDeterminationService::TARGET_HOURS,
            target_income: IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY
          },
          :community_engagement_insufficient_email,
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
