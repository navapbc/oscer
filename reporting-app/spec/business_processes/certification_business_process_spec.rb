# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/event_matchers'

RSpec.describe CertificationBusinessProcess, type: :business_process do
  let(:certification) { create(:certification) }
  let(:certification_case) { CertificationCase.find_by(certification_id: certification.id) }

  before do
    allow(Strata::EventManager).to receive(:publish).and_call_original
  end

  describe 'activity report workflow' do
    it 'transitions through the full workflow and updates member status correctly' do
      # Step 1: Case starts on report_activities
      expect(certification_case.business_process_instance.current_step).to eq("report_activities")
      expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_AWAITING_REPORT)
      expect(certification_case).to be_open

      # Step 2: Member submits activity report
      activity_report = create(:activity_report_application_form,
        certification_case_id: certification_case.id
      )
      activity_report.submit_application
      certification_case.reload

      expect(certification_case.business_process_instance.current_step).to eq("review_activity_report")
      expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_PENDING_REVIEW)
      expect(certification_case).to be_open

      # Step 3: Staff approves activity report
      certification_case.accept_activity_report
      certification_case.reload

      expect(certification_case.business_process_instance.current_step).to eq("end")
      expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_MET_REQUIREMENTS)
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

      it 'transitions to end step' do
        expect(certification_case.business_process_instance.current_step).to eq("end")
      end

      it 'updates member status to not_met_requirements' do
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_NOT_MET_REQUIREMENTS)
      end

      it 'closes the case' do
        expect(certification_case).to be_closed
      end
    end
  end

  describe 'exemption workflow' do
    it 'transitions through exemption workflow and updates member status correctly' do
      # Step 1: Case starts on report_activities
      expect(certification_case.business_process_instance.current_step).to eq("report_activities")
      expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_AWAITING_REPORT)

      # Step 2: Member submits exemption request
      exemption = create(:exemption_application_form,
        certification_case_id: certification_case.id,
        exemption_type: "short_term_hardship"
      )
      exemption.submit_application
      certification_case.reload

      expect(certification_case.business_process_instance.current_step).to eq("review_exemption_claim")
      expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_PENDING_REVIEW)
      expect(certification_case).to be_open

      # Step 3: Staff approves exemption
      certification_case.accept_exemption_request
      certification_case.reload

      expect(certification_case.business_process_instance.current_step).to eq("end")
      expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_EXEMPT)
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
        expect(certification_case.business_process_instance.current_step).to eq("report_activities")
      end

      it 'updates member status to awaiting_report' do
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_AWAITING_REPORT)
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

      # Approve activity report
      expect {
        certification_case.accept_activity_report
      }.to have_published_event("DeterminedRequirementsMet")
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
