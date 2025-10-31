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
    before { allow(Strata::EventManager).to receive(:publish) }

    it 'sets approval status and closes case' do
      certification_case.accept_activity_report
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("approved")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end

    it 'publishes DeterminedRequirementsMet event' do
      certification_case.accept_activity_report

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedRequirementsMet",
        { case_id: certification_case.id }
      )
    end
  end

  describe '#deny_activity_report' do
    before { allow(Strata::EventManager).to receive(:publish) }

    it 'sets denial status' do
      certification_case.deny_activity_report
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("denied")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
    end

    it 'publishes DeterminedRequirementsNotMet event' do
      certification_case.deny_activity_report

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedRequirementsNotMet",
        { case_id: certification_case.id }
      )
    end
  end

  describe '#accept_exemption_request' do
    before { allow(Strata::EventManager).to receive(:publish) }

    it 'sets approval status and closes case' do
      certification_case.accept_exemption_request
      certification_case.reload

      expect(certification_case.exemption_request_approval_status).to eq("approved")
      expect(certification_case.exemption_request_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end

    it 'publishes DeterminedExempt event' do
      certification_case.accept_exemption_request

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedExempt",
        { case_id: certification_case.id }
      )
    end
  end

  describe '#deny_exemption_request' do
    before { allow(Strata::EventManager).to receive(:publish) }

    it 'sets denial status' do
      certification_case.deny_exemption_request
      certification_case.reload

      expect(certification_case.exemption_request_approval_status).to eq("denied")
      expect(certification_case.exemption_request_approval_status_updated_at).to be_present
    end

    it 'publishes DeterminedNotExempt event' do
      certification_case.deny_exemption_request

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedNotExempt",
        { case_id: certification_case.id }
      )
    end
  end

  describe '#determine_ex_parte_exemption' do
    before { allow(Strata::EventManager).to receive(:publish) }

    context 'when applicant is eligible for exemption' do
      it 'sets approval status and closes case' do
        age_fact = Strata::RulesEngine::Fact.new(
          :age_under_19, true, reasons: []
        )
        eligibility_fact = Strata::RulesEngine::Fact.new(
          :age_eligibility, true, reasons: [ age_fact ]
        )
        certification_case.determine_ex_parte_exemption(eligibility_fact)
        certification_case.reload

        expect(certification_case.exemption_request_approval_status).to eq("approved")
        expect(certification_case.exemption_request_approval_status_updated_at).to be_present
        expect(certification_case).to be_closed

        determination = Determination.first

        expect(determination.decision_method).to eq("automated")
        expect(determination.reason).to eq("age_under_19_exempt")
        expect(determination.outcome).to eq("exempt")
        expect(determination.determined_at).to be_present
        expect(determination.determination_data).to eq(eligibility_fact.reasons.to_json)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedExempt",
          { case_id: certification_case.id }
        )
      end
    end


    context 'when applicant is not eligible for exemption' do
      it 'publishes DeterminedNotExempt event' do
        eligibility_fact = Strata::RulesEngine::Fact.new(
          "no-op", false
        )
        certification_case.determine_ex_parte_exemption(eligibility_fact)
        certification_case.reload

        expect(certification_case.exemption_request_approval_status).to be_nil
        expect(certification_case.exemption_request_approval_status_updated_at).to be_nil
        expect(Determination.count).to be_zero

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedNotExempt",
          { case_id: certification_case.id }
        )
      end
    end
  end
end
