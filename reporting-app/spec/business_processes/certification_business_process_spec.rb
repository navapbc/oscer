# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/event_matchers'

RSpec.describe CertificationBusinessProcess, type: :business_process do
  let(:certification) { create(:certification) }
  let(:certification_case) { CertificationCase.find_by(certification_id: certification.id) }

  before do
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(NotificationService).to receive(:send_email_notification)

    # Stub hours compliance service for initial check
    allow(HoursComplianceDeterminationService).to receive(:determine) do |kase|
      Strata::EventManager.publish("DeterminedActionRequired", {
        case_id: kase.id,
        certification_id: kase.certification_id
      })
    end

    # Stub for after activity report approval - default to compliant
    allow(HoursComplianceDeterminationService).to receive(:determine_after_activity_report) do |kase|
      certification = Certification.find(kase.certification_id)
      kase.close!
      certification.record_determination!(
        decision_method: :automated,
        reasons: [ "hours_reported_compliant" ],
        outcome: :compliant,
        determination_data: { total_hours: 85 },
        determined_at: Time.current
      )
      Strata::EventManager.publish("DeterminedHoursMet", {
        case_id: kase.id,
        certification_id: kase.certification_id
      })
    end
  end

  describe 'ex_parte_exemption_check' do
    before do
      certification_case.update!(
        business_process_current_step: CertificationBusinessProcess::EX_PARTE_EXEMPTION_CHECK_STEP
      )
    end

    context 'when applicant is eligible for exemption' do
      let(:age_fact) do
        Strata::RulesEngine::Fact.new(
          :age_under_19, true, reasons: []
        )
      end
      let(:other_age_fact) do
        Strata::RulesEngine::Fact.new(
          :age_over_65, false, reasons: []
        )
      end
      let(:eligibility_fact) do
        Strata::RulesEngine::Fact.new(
          :age_eligibility,
          true,
          reasons: [ age_fact, other_age_fact ]
        )
      end

      it 'transitions to end' do
        # Step 1: Case has been created and is on ex_parte_exemption_check step
        expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::EX_PARTE_EXEMPTION_CHECK_STEP)
        expect(certification_case.member_status).to eq(MemberStatus::AWAITING_REPORT)
        expect(certification_case).to be_open

        # Step 2: System process determines applicant is eligible for exemption
        certification_case.record_exemption_determination(eligibility_fact)
        Strata::EventManager.publish("DeterminedExempt", { case_id: certification_case.id })
        certification_case.reload

        expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::END_STEP)
        expect(certification_case.member_status).to eq(MemberStatus::EXEMPT)
        expect(certification_case).to be_closed
      end
    end

    context 'when applicant is not eligible for exemption' do
      let(:eligibility_fact) do
        Strata::RulesEngine::Fact.new(
          "no-op",
          false
        )
      end

      it 'transitions to ex_parte_community_engagement_check' do
        # Step 1: Case has been created and is on ex_parte_exemption_check step
        expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::EX_PARTE_EXEMPTION_CHECK_STEP)
        expect(certification_case.member_status).to eq(MemberStatus::AWAITING_REPORT)
        expect(certification_case).to be_open

        # Step 2: System process determines applicant is not eligible for exemption
        Strata::EventManager.publish("DeterminedNotExempt", { case_id: certification_case.id })
        certification_case.reload

        # Case transitions to report_activities step is hardcoded in the business process
        expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::REPORT_ACTIVITIES_STEP)
        expect(certification_case.member_status).to eq(MemberStatus::AWAITING_REPORT)
        expect(certification_case).to be_open
      end
    end
  end

  describe 'activity report workflow' do
    it 'transitions through the full workflow and updates member status correctly' do
      # Step 1: Case starts on report_activities
      expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::REPORT_ACTIVITIES_STEP)
      expect(certification_case.member_status).to eq(MemberStatus::AWAITING_REPORT)
      expect(certification_case).to be_open

      # Step 2: Member submits activity report
      activity_report = create(:activity_report_application_form,
        certification_case_id: certification_case.id
      )
      activity_report.submit_application
      certification_case.reload

      expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::REVIEW_ACTIVITY_REPORT_STEP)
      expect(certification_case.member_status).to eq(MemberStatus::PENDING_REVIEW)
      expect(certification_case).to be_open

      # Step 3: Create sufficient hours and approve activity report
      lookback = certification.certification_requirements.continuous_lookback_period
      create(:ex_parte_activity,
             member_id: certification.member_id,
             hours: 85,
             period_start: lookback.start.to_date,
             period_end: lookback.start.to_date.end_of_month)

      certification_case.accept_activity_report
      certification_case.reload

      expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::END_STEP)
      expect(certification_case.member_status).to eq(MemberStatus::COMPLIANT)
      expect(certification_case).to be_closed
    end

    context 'when activity report is denied' do
      before do
        # Submit activity report
        activity_report = create(:activity_report_application_form,
          certification_case_id: certification_case.id
        )
        activity_report.submit_application
        certification_case.reload

        # Staff denies activity report
        certification_case.deny_activity_report
        certification_case.reload
      end

      it 'transitions back to report_activities step (member can resubmit)' do
        expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::REPORT_ACTIVITIES_STEP)
      end

      it 'keeps member status as awaiting_report' do
        expect(certification_case.member_status).to eq(MemberStatus::AWAITING_REPORT)
      end

      it 'keeps the case open' do
        expect(certification_case).not_to be_closed
      end
    end
  end

  describe 'exemption workflow' do
    it 'transitions through exemption workflow and updates member status correctly' do
      # Step 1: Case starts on report_activities
      expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::REPORT_ACTIVITIES_STEP)
      expect(certification_case.member_status).to eq(MemberStatus::AWAITING_REPORT)

      # Step 2: Member submits exemption request
      exemption = create(:exemption_application_form,
        certification_case_id: certification_case.id,
        exemption_type: "short_term_hardship"
      )
      exemption.submit_application
      certification_case.reload

      expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::REVIEW_EXEMPTION_CLAIM_STEP)
      expect(certification_case.member_status).to eq(MemberStatus::PENDING_REVIEW)
      expect(certification_case).to be_open

      # Step 3: Staff approves exemption
      certification_case.accept_exemption_request
      certification_case.reload

      expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::END_STEP)
      expect(certification_case.member_status).to eq(MemberStatus::EXEMPT)
      expect(certification_case).to be_closed
    end

    context 'when exemption is denied' do
      before do
        # Submit exemption request
        exemption = create(:exemption_application_form,
          certification_case_id: certification_case.id,
          exemption_type: "short_term_hardship"
        )
        exemption.submit_application
        certification_case.reload

        # Staff denies exemption
        certification_case.deny_exemption_request
        certification_case.reload
      end

      it 'returns to report_activities step' do
        expect(certification_case.business_process_instance.current_step).to eq(CertificationBusinessProcess::REPORT_ACTIVITIES_STEP)
      end

      it 'updates member status to awaiting_report' do
        expect(certification_case.member_status).to eq(MemberStatus::AWAITING_REPORT)
      end

      it 'keeps the case open' do
        expect(certification_case).to be_open
      end
    end
  end

  describe 'business process events' do
    it 'publishes correct events throughout the workflow' do
      # Create and submit activity report
      activity_report = create(:activity_report_application_form,
        certification_case_id: certification_case.id
      )

      expect {
        activity_report.submit_application
      }.to have_published_event("ActivityReportApplicationFormSubmitted")

      # Create sufficient hours for approval
      lookback = certification.certification_requirements.continuous_lookback_period
      create(:ex_parte_activity,
             member_id: certification.member_id,
             hours: 85,
             period_start: lookback.start.to_date,
             period_end: lookback.start.to_date.end_of_month)

      # Approve activity report - triggers recalculation which publishes DeterminedHoursMet
      expect {
        certification_case.accept_activity_report
      }.to have_published_event("DeterminedHoursMet")
    end

    it 'publishes exemption events' do
      # Create and submit exemption
      exemption = create(:exemption_application_form,
        certification_case_id: certification_case.id,
        exemption_type: "short_term_hardship"
      )

      expect {
        exemption.submit_application
      }.to have_published_event("ExemptionApplicationFormSubmitted")

      # Approve exemption
      expect {
        certification_case.accept_exemption_request
      }.to have_published_event("DeterminedExempt")
    end
  end
end
