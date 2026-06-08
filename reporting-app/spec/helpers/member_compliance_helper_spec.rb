# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberComplianceHelper, type: :helper do
  let(:certification) { create(:certification) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }
  let(:member_status) { MemberStatusService.determine(certification) }

  def compliance_double(exemption_flow_state: nil, due_date: nil)
    instance_double(
      MemberDashboardCompliance,
      exemption_flow_state: exemption_flow_state,
      due_date: due_date
    )
  end

  def build_compliance(activity_report_application_form: nil, exemption_application_form: nil)
    MemberDashboardComplianceService.build(
      certification: certification,
      activity_report_application_form: activity_report_application_form,
      certification_case: certification_case,
      exemption_application_form: exemption_application_form,
      member_status: member_status
    )
  end

  describe "#member_compliance_exemption_badge_variant" do
    it "maps each exemption status token to its Figma badge variant" do
      expect(helper.member_compliance_exemption_badge_variant(MemberDashboardCompliance::EXEMPTION_APPROVED)).to eq("exempt")
      expect(helper.member_compliance_exemption_badge_variant(MemberDashboardCompliance::EXEMPTION_DENIED)).to eq("not-exempt")
      expect(helper.member_compliance_exemption_badge_variant(MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW)).to eq("under-review")
    end

    it "falls back to under-review for unknown tokens" do
      expect(helper.member_compliance_exemption_badge_variant("something_else")).to eq("under-review")
    end
  end

  describe "#member_compliance_due_date" do
    it "formats the due date with the long format" do
      expect(helper.member_compliance_due_date(compliance_double(due_date: Date.new(2026, 6, 30)))).to eq("June 30, 2026")
    end

    it "returns nil when there is no due date" do
      expect(helper.member_compliance_due_date(compliance_double(due_date: nil))).to be_nil
    end
  end

  describe "#member_compliance_coverage_month" do
    let(:compliance) { compliance_double(due_date: Date.new(2026, 6, 30)) }

    it "returns the month following the due date with the year by default" do
      expect(helper.member_compliance_coverage_month(compliance)).to eq("July 2026")
    end

    it "returns just the month name when with_year is false" do
      expect(helper.member_compliance_coverage_month(compliance, with_year: false)).to eq("July")
    end

    it "returns nil when there is no due date" do
      expect(helper.member_compliance_coverage_month(compliance_double(due_date: nil))).to be_nil
    end
  end

  describe "#show_member_compliance_exemption_details_heading?" do
    it "is true for resolved outcomes (approved, denied)" do
      expect(helper.show_member_compliance_exemption_details_heading?(compliance_double(exemption_flow_state: MemberDashboardCompliance::EXEMPTION_APPROVED))).to be(true)
      expect(helper.show_member_compliance_exemption_details_heading?(compliance_double(exemption_flow_state: MemberDashboardCompliance::EXEMPTION_DENIED))).to be(true)
    end

    it "is false for in-flight states (not started, draft, pending review)" do
      [
        MemberDashboardCompliance::EXEMPTION_NOT_STARTED,
        MemberDashboardCompliance::EXEMPTION_DRAFT,
        MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW
      ].each do |state|
        expect(helper.show_member_compliance_exemption_details_heading?(compliance_double(exemption_flow_state: state))).to be(false)
      end
    end
  end

  describe "#member_compliance_exemption_pending_review_screen?" do
    it "is true only for the pending review state" do
      expect(helper.member_compliance_exemption_pending_review_screen?(compliance_double(exemption_flow_state: MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW))).to be(true)
      expect(helper.member_compliance_exemption_pending_review_screen?(compliance_double(exemption_flow_state: MemberDashboardCompliance::EXEMPTION_APPROVED))).to be(false)
    end
  end

  describe "#member_dashboard_get_started_screen?" do
    it "is true when exemption has not started and no application forms exist" do
      expect(helper.member_dashboard_get_started_screen?(build_compliance)).to be(true)
    end

    it "is false when an activity report exists" do
      activity_report = create(:activity_report_application_form, certification_case_id: certification_case.id)

      expect(helper.member_dashboard_get_started_screen?(build_compliance(activity_report_application_form: activity_report))).to be(false)
    end

    it "is false when an exemption application exists" do
      exemption = create(:exemption_application_form, certification_case_id: certification_case.id)

      expect(helper.member_dashboard_get_started_screen?(build_compliance(exemption_application_form: exemption))).to be(false)
    end
  end

  describe "#guard_member_compliance_exemption_outcome_state!" do
    it "does not raise for pending review, approved, or denied" do
      MemberComplianceHelper::EXEMPTION_OUTCOME_FLOW_STATES.each do |state|
        expect { helper.guard_member_compliance_exemption_outcome_state!(state) }.not_to raise_error
      end
    end

    it "raises in test for unexpected flow states" do
      expect {
        helper.guard_member_compliance_exemption_outcome_state!(MemberDashboardCompliance::EXEMPTION_NOT_STARTED)
      }.to raise_error(/unexpected exemption_flow_state/)
    end
  end
end
