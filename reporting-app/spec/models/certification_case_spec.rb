# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationCase, type: :model do
  let(:certification_case) { create(:certification_case) }

  describe '#member_status' do
    context 'when on report_activities step' do
      it 'returns awaiting_report' do
        # Default factory step is "report_activities"
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_AWAITING_REPORT)
      end
    end

    context 'when on review_activity_report step' do
      before do
        certification_case.update!(business_process_current_step: "review_activity_report")
      end

      it 'returns pending_review' do
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_PENDING_REVIEW)
      end
    end

    context 'when on review_exemption_claim step' do
      before do
        certification_case.update!(business_process_current_step: "review_exemption_claim")
      end

      it 'returns pending_review' do
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_PENDING_REVIEW)
      end
    end

    context 'when on end step with approved exemption' do
      before do
        certification_case.update!(
          business_process_current_step: "end",
          exemption_request_approval_status: "approved"
        )
      end

      it 'returns exempt' do
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_EXEMPT)
      end
    end

    context 'when on end step with approved activity report' do
      before do
        certification_case.update!(
          business_process_current_step: "end",
          activity_report_approval_status: "approved"
        )
      end

      it 'returns met_requirements' do
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_MET_REQUIREMENTS)
      end
    end

    context 'when on end step with denied activity report' do
      before do
        certification_case.update!(
          business_process_current_step: "end",
          activity_report_approval_status: "denied"
        )
      end

      it 'returns not_met_requirements' do
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_NOT_MET_REQUIREMENTS)
      end
    end

    context 'when on end step prioritizes exemption over activity report' do
      before do
        certification_case.update!(
          business_process_current_step: "end",
          exemption_request_approval_status: "approved",
          activity_report_approval_status: "approved"
        )
      end

      it 'returns exempt' do
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_EXEMPT)
      end
    end

    context 'when on system process steps' do
      before do
        certification_case.update!(business_process_current_step: "exemption_check")
      end

      it 'returns awaiting_report' do
        expect(certification_case.member_status).to eq(CertificationCase::MEMBER_STATUS_AWAITING_REPORT)
      end
    end
  end

  describe '#accept_activity_report' do
    it 'sets approval status and closes case' do
      allow(Strata::EventManager).to receive(:publish)

      certification_case.accept_activity_report
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("approved")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end

    it 'publishes DeterminedRequirementsMet event' do
      allow(Strata::EventManager).to receive(:publish)

      certification_case.accept_activity_report

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedRequirementsMet",
        { case_id: certification_case.id }
      )
    end
  end

  describe '#deny_activity_report' do
    it 'sets denial status' do
      allow(Strata::EventManager).to receive(:publish)

      certification_case.deny_activity_report
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("denied")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
    end

    it 'publishes DeterminedRequirementsNotMet event' do
      allow(Strata::EventManager).to receive(:publish)

      certification_case.deny_activity_report

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedRequirementsNotMet",
        { case_id: certification_case.id }
      )
    end
  end

  describe '#accept_exemption_request' do
    it 'sets approval status and closes case' do
      allow(Strata::EventManager).to receive(:publish)

      certification_case.accept_exemption_request
      certification_case.reload

      expect(certification_case.exemption_request_approval_status).to eq("approved")
      expect(certification_case.exemption_request_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end

    it 'publishes DeterminedExempt event' do
      allow(Strata::EventManager).to receive(:publish)

      certification_case.accept_exemption_request

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedExempt",
        { case_id: certification_case.id }
      )
    end
  end

  describe '#deny_exemption_request' do
    it 'sets denial status' do
      allow(Strata::EventManager).to receive(:publish)

      certification_case.deny_exemption_request
      certification_case.reload

      expect(certification_case.exemption_request_approval_status).to eq("denied")
      expect(certification_case.exemption_request_approval_status_updated_at).to be_present
    end

    it 'publishes DeterminedNotExempt event' do
      allow(Strata::EventManager).to receive(:publish)

      certification_case.deny_exemption_request

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedNotExempt",
        { case_id: certification_case.id }
      )
    end
  end
end
