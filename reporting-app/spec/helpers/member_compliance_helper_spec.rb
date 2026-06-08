# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberComplianceHelper, type: :helper do
  def compliance_double(exemption_flow_state: nil, due_date: nil)
    instance_double(
      MemberDashboardCompliance,
      exemption_flow_state: exemption_flow_state,
      due_date: due_date
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
end
