# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationCase, type: :model do
  let(:certification_case) { create(:certification_case) }

  describe '#accept_activity_report' do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_return({
        total_hours: 85,
        hours_by_category: { "education" => 50, "employment" => 35 },
        hours_by_source: { ex_parte: 40, activity: 45 },
        ex_parte_activity_ids: [ "ex-1" ],
        activity_ids: [ "act-1" ]
      })
    end

    it 'sets approval status and closes case' do
      certification_case.accept_activity_report
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("approved")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end

    it 'records compliant determination' do
      certification_case.accept_activity_report

      determination = Determination.first

      expect(determination.decision_method).to eq("manual")
      expect(determination.reasons).to include("hours_reported_compliant")
      expect(determination.outcome).to eq("compliant")
      expect(determination.determined_at).to be_present
      expect(determination.determination_data["total_hours"]).to eq(85)
    end

    it 'publishes ActivityReportApproved event' do
      certification_case.accept_activity_report

      expect(Strata::EventManager).to have_received(:publish).with(
        "ActivityReportApproved",
        { case_id: certification_case.id }
      )
    end
  end

  describe '#deny_activity_report' do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_return({
        total_hours: 40,
        hours_by_category: { "education" => 40 },
        hours_by_source: { ex_parte: 30, activity: 10 },
        ex_parte_activity_ids: [ "ex-1" ],
        activity_ids: [ "act-1" ]
      })
    end

    it 'sets denial status and closes case' do
      certification_case.deny_activity_report
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("denied")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end

    it 'records not_compliant determination' do
      certification_case.deny_activity_report

      determination = Determination.first

      expect(determination.decision_method).to eq("manual")
      expect(determination.reasons).to include("hours_reported_insufficient")
      expect(determination.outcome).to eq("not_compliant")
      expect(determination.determined_at).to be_present
      expect(determination.determination_data["total_hours"]).to eq(40)
    end

    it 'publishes ActivityReportDenied event' do
      certification_case.deny_activity_report

      expect(Strata::EventManager).to have_received(:publish).with(
        "ActivityReportDenied",
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
