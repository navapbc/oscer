# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardHelper, type: :helper do
  let(:certification) { create(:certification) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }
  let(:member_status) { MemberStatusService.determine(certification) }
  let(:compliance) do
    MemberDashboardComplianceService.build(
      certification: certification,
      activity_report_application_form: nil,
      certification_case: certification_case,
      exemption_application_form: nil,
      member_status: member_status
    )
  end

  describe "#member_dashboard_get_started_screen?" do
    it "is true when exemption has not started and no application forms exist" do
      expect(helper.member_dashboard_get_started_screen?(compliance)).to be(true)
    end

    it "is false when an activity report exists" do
      activity_report = create(:activity_report_application_form, certification_case_id: certification_case.id)
      compliance_with_activity_report = MemberDashboardComplianceService.build(
        certification: certification,
        activity_report_application_form: activity_report,
        certification_case: certification_case,
        exemption_application_form: nil,
        member_status: member_status
      )

      expect(helper.member_dashboard_get_started_screen?(compliance_with_activity_report)).to be(false)
    end

    it "is false when an exemption application exists" do
      exemption = create(:exemption_application_form, certification_case_id: certification_case.id)
      compliance_with_exemption = MemberDashboardComplianceService.build(
        certification: certification,
        activity_report_application_form: nil,
        certification_case: certification_case,
        exemption_application_form: exemption,
        member_status: member_status
      )

      expect(helper.member_dashboard_get_started_screen?(compliance_with_exemption)).to be(false)
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
