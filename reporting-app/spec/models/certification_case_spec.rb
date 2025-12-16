# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationCase, type: :model do
  let(:certification_case) { create(:certification_case) }

  describe '#accept_activity_report' do
    before do
      allow(Strata::EventManager).to receive(:publish)
    end

    it 'sets approval status' do
      certification_case.accept_activity_report
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("approved")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
    end

    it 'publishes ActivityReportApproved event' do
      certification_case.accept_activity_report

      expect(Strata::EventManager).to have_received(:publish).with(
        "ActivityReportApproved",
        { case_id: certification_case.id }
      )
    end

    it 'does not close the case (business process handles that)' do
      certification_case.accept_activity_report
      certification_case.reload

      expect(certification_case).not_to be_closed
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

    it 'publishes ActivityReportDenied event' do
      certification_case.deny_activity_report

      expect(Strata::EventManager).to have_received(:publish).with(
        "ActivityReportDenied",
        { case_id: certification_case.id }
      )
    end

    it 'does not close the case (member can resubmit)' do
      certification_case.deny_activity_report
      certification_case.reload

      expect(certification_case).not_to be_closed
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

      determination = Determination.first

      expect(determination.decision_method).to eq("manual")
      expect(determination.reasons).to include("exemption_request_compliant")
      expect(determination.outcome).to eq("exempt")
      expect(determination.determined_at).to be_present
      expect(determination.determination_data).to eq({ "exemption_type" => "placeholder" })
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

  describe '#record_exemption_determination' do
    # Model only records state - service handles conditional logic and events

    it 'sets approval status and closes case' do
      age_fact = Strata::RulesEngine::Fact.new(
        :age_under_19, true, reasons: []
      )
      eligibility_fact = Strata::RulesEngine::Fact.new(
        :age_eligibility, true, reasons: [ age_fact ]
      )
      certification_case.record_exemption_determination(eligibility_fact)
      certification_case.reload

      expect(certification_case.exemption_request_approval_status).to eq("approved")
      expect(certification_case.exemption_request_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end

    it 'creates determination with correct attributes' do
      age_fact = Strata::RulesEngine::Fact.new(
        :age_under_19, true, reasons: []
      )
      eligibility_fact = Strata::RulesEngine::Fact.new(
        :age_eligibility, true, reasons: [ age_fact ]
      )
      certification_case.record_exemption_determination(eligibility_fact)

      determination = Determination.first

      expect(determination.decision_method).to eq("automated")
      expect(determination.reasons).to include("age_under_19_exempt")
      expect(determination.outcome).to eq("exempt")
      expect(determination.determined_at).to be_present
      expect(determination.determination_data).to eq(eligibility_fact.reasons.to_json)
    end

    it 'records multiple reasons (age and pregnancy)' do
      age_fact = Strata::RulesEngine::Fact.new(
        :age_under_19, true, reasons: []
      )
      pregnant_fact = Strata::RulesEngine::Fact.new(
        :is_pregnant, true, reasons: []
      )
      eligibility_fact = Strata::RulesEngine::Fact.new(
        :eligible_for_exemption, true, reasons: [ age_fact, pregnant_fact ]
      )
      certification_case.record_exemption_determination(eligibility_fact)

      determination = Determination.first

      expect(determination.reasons).to include("age_under_19_exempt", "pregnancy_exempt")
      expect(determination.outcome).to eq("exempt")
    end
  end
end
