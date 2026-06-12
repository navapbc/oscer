# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardHelper, type: :helper do
  before do
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  describe "#should_show_submit_new_exemption_form?" do
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification_id: certification.id) }
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
end
