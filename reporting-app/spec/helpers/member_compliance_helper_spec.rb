# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberComplianceHelper, type: :helper do
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

  describe "#member_compliance_get_started_screen?" do
    it "is true when exemption has not started and no activity report exists" do
      expect(helper.member_compliance_get_started_screen?(compliance, activity_report: nil)).to be(true)
    end

    it "is false when an activity report exists" do
      activity_report = create(:activity_report_application_form, certification_case_id: certification_case.id)

      expect(helper.member_compliance_get_started_screen?(compliance, activity_report: activity_report)).to be(false)
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

      expect(helper.member_compliance_get_started_screen?(compliance_with_exemption, activity_report: nil)).to be(false)
    end
  end
end
