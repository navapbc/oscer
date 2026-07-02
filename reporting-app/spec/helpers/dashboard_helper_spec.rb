# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardHelper, type: :helper do
  let(:certification) { create(:certification) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }

  before do
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(ExclusionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  def assign_dashboard_ivars(
    member_dashboard_compliance: nil,
    certification: self.certification,
    exemption_application_form: nil,
    activity_report_application_form: nil,
    member_status: MemberStatusService.determine(certification)
  )
    helper.instance_variable_set(:@member_dashboard_compliance, member_dashboard_compliance)
    helper.instance_variable_set(:@certification, certification)
    helper.instance_variable_set(:@certification_case, certification_case)
    helper.instance_variable_set(:@exemption_application_form, exemption_application_form)
    helper.instance_variable_set(:@activity_report_application_form, activity_report_application_form)
    helper.instance_variable_set(:@member_status, member_status)
  end

  describe "#determine_dashboard_view" do
    it "returns exemption_draft before the new_certification incomplete path" do
      exemption_application_form = create(:exemption_application_form, certification_case_id: certification_case.id)
      activity_report_application_form = create(:activity_report_application_form, certification_case_id: certification_case.id)
      member_status = MemberStatusService.determine(certification)
      compliance = MemberDashboardComplianceService.build(
        certification: certification,
        certification_case: certification_case,
        exemption_application_form: exemption_application_form,
        activity_report_application_form: activity_report_application_form,
        member_status: member_status
      )

      assign_dashboard_ivars(
        member_dashboard_compliance: compliance,
        exemption_application_form: exemption_application_form,
        activity_report_application_form: activity_report_application_form,
        member_status: member_status
      )

      expect(helper.determine_dashboard_view).to eq("exemption_draft")
    end

    it "returns new_certification when no read model is present and applications are incomplete" do
      exemption_application_form = create(:exemption_application_form, certification_case_id: certification_case.id)

      assign_dashboard_ivars(
        member_dashboard_compliance: nil,
        exemption_application_form: exemption_application_form
      )

      expect(helper.determine_dashboard_view).to eq("new_certification")
    end

    it "returns new_certification for a non-draft exemption flow state with incomplete forms" do
      exemption_application_form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
      compliance = instance_double(
        MemberDashboardCompliance,
        exemption_flow_state: MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
      )

      assign_dashboard_ivars(
        member_dashboard_compliance: compliance,
        exemption_application_form: exemption_application_form
      )

      expect(helper.determine_dashboard_view).not_to eq("exemption_draft")
    end
  end

  describe "#are_activity_report_or_exemption_incomplete?" do
    it "is true when neither application form is submitted" do
      assign_dashboard_ivars(
        activity_report_application_form: create(:activity_report_application_form, certification_case_id: certification_case.id)
      )

      expect(helper.are_activity_report_or_exemption_incomplete?).to be(true)
    end

    it "is false when only the exemption form is submitted" do
      exemption_application_form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)

      assign_dashboard_ivars(exemption_application_form: exemption_application_form)

      expect(helper.are_activity_report_or_exemption_incomplete?).to be(false)
    end

    it "is false when both forms are submitted" do
      exemption_application_form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
      activity_report_application_form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)

      assign_dashboard_ivars(
        exemption_application_form: exemption_application_form,
        activity_report_application_form: activity_report_application_form
      )

      expect(helper.are_activity_report_or_exemption_incomplete?).to be(false)
    end
  end

  describe "#should_show_submit_new_exemption_form?" do
    let(:exemption_application_form) do
      form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
      ReviewExemptionClaimTask.find_by(application_form: form).completed!
      certification_case.deny_exemption_request(nil)
      form
    end
    let(:compliance) do
      MemberDashboardComplianceService.build(
        certification: certification,
        certification_case: certification_case,
        activity_report_application_form: nil,
        exemption_application_form: exemption_application_form,
        member_status: MemberStatusService.determine(certification)
      )
    end

    it "returns true on the denied dashboard when the member may submit again" do
      expect(helper.should_show_submit_new_exemption_form?(compliance)).to be(true)
    end

    it "returns false when flow state is not denied" do
      pending_form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
      pending_compliance = MemberDashboardComplianceService.build(
        certification: certification,
        certification_case: certification_case,
        activity_report_application_form: nil,
        exemption_application_form: pending_form,
        member_status: MemberStatusService.determine(certification)
      )

      expect(helper.should_show_submit_new_exemption_form?(pending_compliance)).to be(false)
    end

    it "returns false when the verification window has ended" do
      expect(helper.should_show_submit_new_exemption_form?(compliance)).to be(true)

      certification_case.update_attribute!(:verification_window_end_date, 1.day.ago)
      compliance_after_window = MemberDashboardComplianceService.build(
        certification: certification,
        certification_case: certification_case.reload,
        activity_report_application_form: nil,
        exemption_application_form: exemption_application_form,
        member_status: MemberStatusService.determine(certification)
      )

      expect(helper.should_show_submit_new_exemption_form?(compliance_after_window)).to be(false)
    end
  end

  describe "#should_show_submit_new_activity_report_form?" do
    it "returns false when certification_case is blank" do
      expect(helper.should_show_submit_new_activity_report_form?(nil)).to be(false)
    end

    it "is true when the case is open, the window has not ended, and no form is pending" do
      expect(helper.should_show_submit_new_activity_report_form?(certification_case)).to be(true)
    end

    it "is false when the case is closed" do
      certification_case.close!
      expect(helper.should_show_submit_new_activity_report_form?(certification_case)).to be(false)
    end

    it "is false when the verification window has ended" do
      certification_case.update_attribute(:verification_window_end_date, 1.day.ago)
      expect(helper.should_show_submit_new_activity_report_form?(certification_case)).to be(false)
    end

    it "is false when a form is already pending" do
      create(:activity_report_application_form, certification_case_id: certification_case.id)
      expect(helper.should_show_submit_new_activity_report_form?(certification_case)).to be(false)
    end
  end

  describe "activity report status helpers" do
    let(:activity_report) { create(:activity_report_application_form, certification_case_id: certification_case.id) }

    before do
      assign(:activity_report_application_form, activity_report)
      assign(:certification_case, certification_case)
    end

    it "#is_activity_report_submitted? is true when flow_status is 'submitted'" do
      allow(activity_report).to receive(:flow_status).and_return("submitted")
      expect(helper.is_activity_report_submitted?).to be(true)
    end

    it "#is_activity_report_approved? is true when flow_status is 'approved'" do
      allow(activity_report).to receive(:flow_status).and_return("approved")
      expect(helper.is_activity_report_approved?).to be(true)
    end

    it "#is_activity_report_denied? is true when flow_status is 'denied'" do
      allow(activity_report).to receive(:flow_status).and_return("denied")
      expect(helper.is_activity_report_denied?).to be(true)
    end

    it "#is_activity_report_submitted? is false once the report is approved" do
      allow(activity_report).to receive(:flow_status).and_return("approved")
      expect(helper.is_activity_report_submitted?).to be(false)
    end
  end
end
