# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationCase, type: :model do
  let(:certification_case) { create(:certification_case) }

  describe '#accept_activity_report' do
    before { allow(Strata::EventManager).to receive(:publish) }

    it 'sets approval status and closes case' do
      certification_case.accept_activity_report
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("approved")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed


      determination = Determination.first

      expect(determination.decision_method).to eq("manual")
      expect(determination.reasons).to include("hours_reported_compliant")
      expect(determination.outcome).to eq("compliant")
      expect(determination.determined_at).to be_present
      expect(determination.determination_data).to eq({ "activity_type" => "placeholder", "activity_hours" => 0, "income" => 0 })
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

  describe '#determine_ex_parte_exemption' do
    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    context 'when member is eligible for exemption' do
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
        expect(determination.reasons).to include("age_under_19_exempt")
        expect(determination.outcome).to eq("exempt")
        expect(determination.determined_at).to be_present
        expect(determination.determination_data).to eq(eligibility_fact.reasons.to_json)

        expect(Strata::EventManager).to have_received(:publish).with(
          "DeterminedExempt",
          { case_id: certification_case.id }
        )
      end

      it 'sets approval status when eligible via pregnancy only' do
        pregnant_fact = Strata::RulesEngine::Fact.new(
          :is_pregnant, true, reasons: []
        )
        eligibility_fact = Strata::RulesEngine::Fact.new(
          :eligible_for_exemption, true, reasons: [ pregnant_fact ]
        )
        certification_case.determine_ex_parte_exemption(eligibility_fact)
        certification_case.reload

        expect(certification_case.exemption_request_approval_status).to eq("approved")
        expect(certification_case.exemption_request_approval_status_updated_at).to be_present
        expect(certification_case).to be_closed

        determination = Determination.first

        expect(determination.decision_method).to eq("automated")
        expect(determination.reasons).to include("pregnancy_exempt")
        expect(determination.outcome).to eq("exempt")
      end

      it 'sets approval status with multiple reasons (age and pregnancy)' do
        age_fact = Strata::RulesEngine::Fact.new(
          :age_under_19, true, reasons: []
        )
        pregnant_fact = Strata::RulesEngine::Fact.new(
          :is_pregnant, true, reasons: []
        )
        eligibility_fact = Strata::RulesEngine::Fact.new(
          :eligible_for_exemption, true, reasons: [ age_fact, pregnant_fact ]
        )
        certification_case.determine_ex_parte_exemption(eligibility_fact)
        certification_case.reload

        expect(certification_case.exemption_request_approval_status).to eq("approved")
        expect(certification_case).to be_closed

        determination = Determination.first

        expect(determination.decision_method).to eq("automated")
        expect(determination.reasons).to include("age_under_19_exempt", "pregnancy_exempt")
        expect(determination.outcome).to eq("exempt")
      end

      it 'sends exempt notification email' do
        age_fact = Strata::RulesEngine::Fact.new(
          :age_under_19, true, reasons: []
        )
        eligibility_fact = Strata::RulesEngine::Fact.new(
          :age_eligibility, true, reasons: [ age_fact ]
        )
        certification_case.determine_ex_parte_exemption(eligibility_fact)

        expect(NotificationService).to have_received(:send_email_notification)
      end
    end


    context 'when member is not eligible for exemption' do
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

      it 'sends action required notification email' do
        eligibility_fact = Strata::RulesEngine::Fact.new(
          "no-op", false
        )
        certification_case.determine_ex_parte_exemption(eligibility_fact)

        certification = Certification.find(certification_case.certification_id)
        expect(NotificationService).to have_received(:send_email_notification).with(
          MemberMailer,
          { certification: certification },
          :action_required_email,
          [ certification.member_email ]
        )
      end
    end
  end
end
