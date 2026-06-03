# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationCase, type: :model do
  let(:certification_case) { create(:certification_case) }
  let(:user) { create(:user) }

  # Prevent real external CE from recording a compliant determination during certification bootstrap
  # (Income aggregate can meet threshold and close the case before examples run).
  before do
    allow(NotificationService).to receive(:send_email_notification)
    allow(CommunityEngagementCheckService).to receive(:determine) do |kase|
      Strata::EventManager.publish("DeterminedCommunityEngagementActionRequired", {
        case_id: kase.id,
        certification_id: kase.certification_id
      })
    end
  end

  describe '#accept_activity_report' do
    let(:application_form) { create(:activity_report_application_form) }

    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_return({
        total_hours: 85,
        hours_by_category: { "education" => 50, "employment" => 35 },
        hours_by_source: { external: 40, activity: 45 },
        external_hourly_activity_ids: [ "ex-1" ],
        activity_ids: [ "act-1" ]
      })
    end

    it 'sets approval status and closes case' do
      certification_case.accept_activity_report(user, application_form)
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("approved")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end

    it 'records compliant determination' do
      certification_case.accept_activity_report(user, application_form)

      determination = Determination.first

      expect(determination.decision_method).to eq("manual")
      expect(determination.reasons).to include("hours_reported_compliant")
      expect(determination.outcome).to eq("compliant")
      expect(determination.determined_at).to be_present
      expect(determination.determination_data["total_hours"]).to eq(85)
    end

    it 'aggregates hours against the given application form' do
      certification_case.accept_activity_report(user, application_form)

      expect(HoursComplianceDeterminationService).to have_received(:aggregate_hours_for_certification)
        .with(anything, application_form: application_form)
    end

    it 'publishes ActivityReportApproved event' do
      certification_case.accept_activity_report(user, application_form)
      expect(Strata::EventManager).to have_received(:publish).with(
        "ActivityReportApproved",
        { case_id: certification_case.id, certification_id: certification_case.certification_id }
      )
    end

    it 'logs decision to audit log' do
      certification = Certification.find(certification_case.certification_id)
      expect do
        certification_case.accept_activity_report(user, application_form)
      end.to change { Strata::AuditLine.where(actor: user, subject: certification, action: "case.activity_report.approved").count }.by(1)
    end
  end

  describe '#deny_activity_report' do
    let(:application_form) { create(:activity_report_application_form) }

    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_return({
        total_hours: 40,
        hours_by_category: { "education" => 40 },
        hours_by_source: { external: 30, activity: 10 },
        external_hourly_activity_ids: [ "ex-1" ],
        activity_ids: [ "act-1" ]
      })
    end

    it 'sets denial status and closes case' do
      certification_case.deny_activity_report(user, application_form)
      certification_case.reload

      expect(certification_case.activity_report_approval_status).to eq("denied")
      expect(certification_case.activity_report_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end

    it 'records not_compliant determination' do
      certification_case.deny_activity_report(user, application_form)

      determination = Determination.first

      expect(determination.decision_method).to eq("manual")
      expect(determination.reasons).to include("hours_reported_insufficient")
      expect(determination.outcome).to eq("not_compliant")
      expect(determination.determined_at).to be_present
      expect(determination.determination_data["total_hours"]).to eq(40)
    end

    it 'aggregates hours against the given application form' do
      certification_case.deny_activity_report(user, application_form)

      expect(HoursComplianceDeterminationService).to have_received(:aggregate_hours_for_certification)
        .with(anything, application_form: application_form)
    end

    it 'publishes ActivityReportDenied event' do
      certification_case.deny_activity_report(user, application_form)

      expect(Strata::EventManager).to have_received(:publish).with(
        "ActivityReportDenied",
        { case_id: certification_case.id, certification_id: certification_case.certification_id, application_form_id: application_form.id }
      )
    end

    it 'logs decision to audit log' do
      certification = Certification.find(certification_case.certification_id)
      expect do
        certification_case.deny_activity_report(user, application_form)
      end.to change { Strata::AuditLine.where(actor: user, subject: certification, action: "case.activity_report.denied").count }.by(1)
    end
  end

  describe '#accept_exemption_request' do
    before { allow(Strata::EventManager).to receive(:publish) }

    it 'sets approval status and closes case' do
      certification_case.accept_exemption_request(user)
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
      certification_case.accept_exemption_request(user)

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedExempt",
        { case_id: certification_case.id, certification_id: certification_case.certification_id }
      )
    end

    it 'logs decision to audit log' do
      certification = Certification.find(certification_case.certification_id)
      expect do
        certification_case.accept_exemption_request(user)
      end.to change { Strata::AuditLine.where(actor: user, subject: certification, action: "case.exemption.approved").count }.by(1)
    end
  end

  describe '#deny_exemption_request' do
    before { allow(Strata::EventManager).to receive(:publish) }

    it 'sets denial status' do
      certification_case.deny_exemption_request(user)
      certification_case.reload

      expect(certification_case.exemption_request_approval_status).to eq("denied")
      expect(certification_case.exemption_request_approval_status_updated_at).to be_present
    end

    it 'publishes DeterminedNotExempt event' do
      certification_case.deny_exemption_request(user)

      expect(Strata::EventManager).to have_received(:publish).with(
        "DeterminedNotExempt",
        { case_id: certification_case.id, certification_id: certification_case.certification_id }
      )
    end

    it 'logs decision to audit log' do
      certification = Certification.find(certification_case.certification_id)
      expect do
        certification_case.deny_exemption_request(user)
      end.to change { Strata::AuditLine.where(actor: user, subject: certification, action: "case.exemption.denied").count }.by(1)
    end
  end

  describe '#record_exemption_determination' do
    # Model only records state - service handles conditional logic and events
    before { stub_const("MockSubmitter", Class.new { include Strata::VirtualActor }) }


    it 'sets approval status and closes case' do
      age_fact = Strata::RulesEngine::Fact.new(
        :age_under_19, true, reasons: []
      )
      eligibility_fact = Strata::RulesEngine::Fact.new(
        :age_eligibility, true, reasons: [ age_fact ]
      )
      certification_case.record_exemption_determination(eligibility_fact, MockSubmitter)
      certification_case.reload

      expect(certification_case.exemption_request_approval_status).to eq("approved")
      expect(certification_case.exemption_request_approval_status_updated_at).to be_present
      expect(certification_case).to be_closed
    end


    it "logs approved decision to audit log" do
      age_fact = Strata::RulesEngine::Fact.new(
        :age_under_19, true, reasons: []
      )
      eligibility_fact = Strata::RulesEngine::Fact.new(
        :age_eligibility, true, reasons: [ age_fact ]
      )
      certification = Certification.find(certification_case.certification_id)
      expect do
        certification_case.record_exemption_determination(eligibility_fact, MockSubmitter)
      end.to change { Strata::AuditLine.where(subject: certification, actor_type: MockSubmitter.name, action: "case.exemption.approved").count }.by(1)
    end

    it 'creates determination with correct attributes' do
      age_fact = Strata::RulesEngine::Fact.new(
        :age_under_19, true, reasons: []
      )
      eligibility_fact = Strata::RulesEngine::Fact.new(
        :age_eligibility, true, reasons: [ age_fact ]
      )
      certification_case.record_exemption_determination(eligibility_fact, MockSubmitter)

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
      certification_case.record_exemption_determination(eligibility_fact, MockSubmitter)

      determination = Determination.first

      expect(determination.reasons).to include("age_under_19_exempt", "pregnancy_exempt")
      expect(determination.outcome).to eq("exempt")
    end
  end

  describe "#record_external_ce_combined_assessment" do
    before { stub_const("MockSubmitter", Class.new { include Strata::VirtualActor }) }

    def latest_determination_for(certification_id)
      Determination.unscope(:order).where(subject_id: certification_id).order(created_at: :desc).first
    end

    let(:certification) { Certification.find(certification_case.certification_id) }

    let(:hours_data) do
      {
        total_hours: 50,
        hours_by_category: {},
        hours_by_source: { external: 40.0, activity: 10.0 },
        external_hourly_activity_ids: [],
        activity_ids: []
      }
    end
    let(:income_data) do
      {
        total_income: BigDecimal("400"),
        income_by_source: { external: BigDecimal("400"), activity: BigDecimal("0") },
        external_income_activity_ids: [],
        activity_ids: [],
        period_start: Date.current,
        period_end: Date.current
      }
    end

    it "stores not_compliant with both insufficient reasons when both tracks fail" do
      certification_case.record_external_ce_combined_assessment(
        actor: MockSubmitter,
        certification: certification,
        hours_data: hours_data,
        income_data: income_data,
        hours_ok: false,
        income_ok: false
      )

      determination = latest_determination_for(certification_case.certification_id)
      expect(determination.outcome).to eq("not_compliant")
      expect(determination.reasons).to contain_exactly(
        "hours_reported_insufficient",
        "income_reported_insufficient"
      )
      expect(determination.determination_data["satisfied_by"]).to eq(Determination::SATISFIED_BY_NEITHER)
    end

    it "logs denied decision to audit log" do
      expect do
        certification_case.record_external_ce_combined_assessment(
          actor: MockSubmitter,
          certification: certification,
          hours_data:,
          income_data:,
          hours_ok: false,
          income_ok: false
        )
      end.to change { Strata::AuditLine.where(subject: certification, actor_type: MockSubmitter.name, action: "case.activity_report.denied").count }.by(1)
    end

    it "stores compliant when only income_ok" do
      certification_case.record_external_ce_combined_assessment(
        actor: MockSubmitter,
        certification: certification,
        hours_data: hours_data,
        income_data: income_data,
        hours_ok: false,
        income_ok: true
      )

      determination = latest_determination_for(certification_case.certification_id)
      expect(determination.outcome).to eq("compliant")
      expect(determination.reasons).to eq([ "income_reported_compliant" ])
      expect(certification_case.reload).to be_closed
    end

    it "logs approved decision to audit log" do
      expect do
        certification_case.record_external_ce_combined_assessment(
          actor: MockSubmitter,
          certification: certification,
          hours_data:,
          income_data:,
          hours_ok: false,
          income_ok: true
        )
      end.to change { Strata::AuditLine.where(subject: certification, actor_type: MockSubmitter.name, action: "case.activity_report.approved").count }.by(1)
    end
  end

  describe ".open_certification_id_for_member" do
    let(:certification) { create(:certification) }

    it "returns the certification id when an open case exists" do
      kase = create(:certification_case, certification: certification)

      expect(described_class.open_certification_id_for_member(certification.member_id)).to eq(kase.certification_id)
    end

    it "returns nil when the only case for the member is closed" do
      kase = create(:certification_case, certification: certification)
      kase.close!

      expect(described_class.open_certification_id_for_member(certification.member_id)).to be_nil
    end

    it "returns the latest certification when multiple open cases exist for the member" do
      member_id = create(:certification).member_id
      older = create(:certification, member_id: member_id)
      create(:certification_case, certification: older)
      newer = travel_to(1.hour.from_now) { create(:certification, member_id: member_id) }
      create(:certification_case, certification: newer)

      expect(described_class.open_certification_id_for_member(member_id)).to eq(newer.id)
    end
  end

  describe ".open_verification_window" do
    it "sets the window at the expected duration" do
      certification_case.open_verification_window
      start_date = Date.today
      duration = CertificationCase::VERIFICATION_WINDOW_DURATION_DAYS

      expect(certification_case.verification_window_start_date).to eq start_date
      expect(certification_case.verification_window_end_date).to eq start_date + duration
    end

    it "doesn't set the window if it's already set" do
      # set the window a week ago
      past_start_date = Date.today - 7
      travel_to(past_start_date) do
        certification_case.open_verification_window
      end

      # verify
      expect(certification_case.verification_window_start_date).to eq past_start_date

      # try to set it again now
      start_date = Date.today
      certification_case.open_verification_window

      # verify
      expect(certification_case.verification_window_start_date).not_to eq start_date
    end
  end
end
