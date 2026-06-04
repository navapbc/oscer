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

  describe "#member_compliance_period_label" do
    it "formats a continuous lookback range in uppercase month tokens" do
      allow(compliance).to receive_messages(
        show_income_summary: true,
        period_start_on: Date.new(2026, 6, 1),
        period_end_on: Date.new(2026, 8, 1)
      )

      expect(helper.member_compliance_period_label(compliance)).to eq("JUN-AUG 2026")
    end
  end

  describe "#member_compliance_due_date" do
    it "localizes the due date" do
      allow(compliance).to receive(:due_date).and_return(Date.new(2026, 8, 15))

      expect(helper.member_compliance_due_date(compliance)).to eq(
        I18n.l(Date.new(2026, 8, 15), format: :long)
      )
    end
  end

  describe "#member_compliance_coverage_month" do
    it "returns the month after the due date with the year" do
      allow(compliance).to receive(:due_date).and_return(Date.new(2026, 6, 30))

      expect(helper.member_compliance_coverage_month(compliance)).to eq("July 2026")
    end

    it "returns just the month name when with_year is false" do
      allow(compliance).to receive(:due_date).and_return(Date.new(2026, 1, 31))

      expect(helper.member_compliance_coverage_month(compliance, with_year: false)).to eq("February")
    end

    it "is nil without a due date" do
      allow(compliance).to receive(:due_date).and_return(nil)

      expect(helper.member_compliance_coverage_month(compliance)).to be_nil
    end
  end

  describe "#member_compliance_exemption_alert_variant" do
    MemberComplianceHelper::EXEMPTION_ALERT_VARIANTS.each do |state, variant|
      it "maps #{state} to #{variant}" do
        allow(compliance).to receive(:exemption_flow_state).and_return(state)

        expect(helper.member_compliance_exemption_alert_variant(compliance)).to eq(variant)
      end
    end

    it "defaults unknown states to info" do
      allow(compliance).to receive(:exemption_flow_state).and_return("unknown")

      expect(helper.member_compliance_exemption_alert_variant(compliance)).to eq("info")
    end
  end

  describe "#member_compliance_report_status_variant" do
    MemberComplianceHelper::REPORT_STATUS_VARIANTS.each do |token, variant|
      it "maps #{token} to #{variant}" do
        allow(compliance).to receive(:report_status_token).and_return(token)

        expect(helper.member_compliance_report_status_variant(compliance)).to eq(variant)
      end
    end

    it "defaults unknown tokens to in-progress" do
      allow(compliance).to receive(:report_status_token).and_return("unknown")

      expect(helper.member_compliance_report_status_variant(compliance)).to eq("in-progress")
    end

    it "shows in-progress before the due date while the activity report is still editable" do
      form = build_stubbed(:activity_report_application_form)
      allow(form).to receive(:submitted?).and_return(false)
      allow(compliance).to receive_messages(report_status_token: MemberStatus::DASHBOARD_REPORT_NOT_COMPLIANT, due_date: 1.month.from_now.to_date)

      expect(helper.member_compliance_report_status_variant(compliance, activity_report: form)).to eq("in-progress")
    end
  end

  describe "#member_compliance_income_reported_progress_modifier" do
    let(:activity_report) { build_stubbed(:activity_report_application_form) }

    before do
      allow(activity_report).to receive(:submitted?).and_return(false)
      allow(compliance).to receive_messages(show_income_summary: true, income_percent_of_requirement: 0.0, due_date: 1.month.from_now.to_date)
    end

    it "returns warning while income reporting is in progress below target" do
      allow(compliance).to receive(:report_status_token).and_return(MemberStatus::DASHBOARD_REPORT_NOT_COMPLIANT)

      expect(helper.member_compliance_income_reported_progress_modifier(compliance, activity_report:)).to eq("warning")
    end

    it "returns compliant when the income requirement is met" do
      allow(compliance).to receive_messages(income_percent_of_requirement: 100.0, report_status_token: MemberStatus::DASHBOARD_REPORT_COMPLIANT)

      expect(helper.member_compliance_income_reported_progress_modifier(compliance, activity_report:)).to eq("compliant")
    end
  end

  describe "#member_compliance_hours_reported_progress_modifier" do
    let(:activity_report) { build_stubbed(:activity_report_application_form) }

    before do
      allow(activity_report).to receive(:submitted?).and_return(false)
      allow(compliance).to receive_messages(show_income_summary: false, hours_percent_of_requirement: 0.0, due_date: 1.month.from_now.to_date)
    end

    it "returns warning while hours reporting is in progress below target" do
      allow(compliance).to receive(:report_status_token).and_return(MemberStatus::DASHBOARD_REPORT_NOT_COMPLIANT)

      expect(helper.member_compliance_hours_reported_progress_modifier(compliance, activity_report:)).to eq("warning")
    end

    it "returns compliant when the hours requirement is met" do
      allow(compliance).to receive_messages(hours_percent_of_requirement: 100.0, report_status_token: MemberStatus::DASHBOARD_REPORT_COMPLIANT)

      expect(helper.member_compliance_hours_reported_progress_modifier(compliance, activity_report:)).to eq("compliant")
    end

    it "returns nil on the income path" do
      allow(compliance).to receive(:show_income_summary).and_return(true)

      expect(helper.member_compliance_hours_reported_progress_modifier(compliance, activity_report:)).to be_nil
    end
  end

  describe "#member_compliance_exemption_badge_variant" do
    MemberComplianceHelper::EXEMPTION_BADGE_VARIANTS.each do |status, variant|
      it "maps #{status} to #{variant}" do
        expect(helper.member_compliance_exemption_badge_variant(status)).to eq(variant)
      end
    end

    it "defaults unknown statuses to under-review" do
      expect(helper.member_compliance_exemption_badge_variant("unknown")).to eq("under-review")
    end
  end

  describe "#member_compliance_report_status_subcopy" do
    before do
      allow(compliance).to receive(:due_date).and_return(Date.new(2026, 8, 15))
    end

    it "returns in-progress copy with due date" do
      allow(compliance).to receive(:report_status_token).and_return(MemberStatus::DASHBOARD_REPORT_IN_PROGRESS)

      expect(helper.member_compliance_report_status_subcopy(compliance)).to eq(
        I18n.t(
          "dashboard.member_compliance.progress_cards.report_status_subcopy.in_progress",
          due_date: I18n.l(Date.new(2026, 8, 15), format: :long)
        )
      )
    end

    it "returns under_review copy without requiring submit-before wording" do
      allow(compliance).to receive(:report_status_token).and_return(MemberStatus::DASHBOARD_REPORT_UNDER_REVIEW)

      expect(helper.member_compliance_report_status_subcopy(compliance)).to eq(
        I18n.t("dashboard.member_compliance.progress_cards.report_status_subcopy.under_review")
      )
    end

    it "returns an empty string for an unknown report status token" do
      allow(compliance).to receive(:report_status_token).and_return("unknown_status")

      expect(helper.member_compliance_report_status_subcopy(compliance)).to eq("")
    end
  end

  describe "#show_member_compliance_exemption_details_heading?" do
    it "is false for not_started, draft, and pending review onboarding states" do
      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_NOT_STARTED)
      expect(helper.show_member_compliance_exemption_details_heading?(compliance)).to be false

      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_DRAFT)
      expect(helper.show_member_compliance_exemption_details_heading?(compliance)).to be false

      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW)
      expect(helper.show_member_compliance_exemption_details_heading?(compliance)).to be false
    end

    it "is true once exemption is approved or denied" do
      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_APPROVED)
      expect(helper.show_member_compliance_exemption_details_heading?(compliance)).to be true

      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_DENIED)
      expect(helper.show_member_compliance_exemption_details_heading?(compliance)).to be true
    end
  end

  describe "#member_compliance_exemption_pending_review_screen?" do
    it "is true when exemption is pending review" do
      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW)
      expect(helper.member_compliance_exemption_pending_review_screen?(compliance)).to be true
    end
  end

  describe "#member_compliance_exemption_draft_screen?" do
    it "is true when exemption is in draft" do
      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_DRAFT)
      expect(helper.member_compliance_exemption_draft_screen?(compliance)).to be true
    end
  end

  describe "#member_compliance_get_started_screen?" do
    it "is true when exemption has not started and there is no activity report" do
      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_NOT_STARTED)

      expect(helper.member_compliance_get_started_screen?(compliance, activity_report: nil)).to be true
    end

    it "is false when an activity report exists" do
      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_NOT_STARTED)
      form = build_stubbed(:activity_report_application_form)

      expect(helper.member_compliance_get_started_screen?(compliance, activity_report: form)).to be false
    end
  end

  describe "#show_member_compliance_reporting_section?" do
    it "is false when exempt" do
      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_APPROVED)

      expect(helper.show_member_compliance_reporting_section?(compliance, activity_report: nil)).to be false
    end

    it "is false when exemption has not started and there is no activity report" do
      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_NOT_STARTED)

      expect(helper.show_member_compliance_reporting_section?(compliance, activity_report: nil)).to be false
    end

    it "is true when exemption was denied" do
      allow(compliance).to receive(:exemption_flow_state).and_return(MemberDashboardCompliance::EXEMPTION_DENIED)

      expect(helper.show_member_compliance_reporting_section?(compliance, activity_report: nil)).to be true
    end
  end

  describe "#member_compliance_reporting_continue_button_label" do
    it "returns continue reporting activities on the hours-only path" do
      allow(compliance).to receive(:show_income_summary).and_return(false)
      expect(helper.member_compliance_reporting_continue_button_label(compliance)).to eq(
        I18n.t("dashboard.member_compliance.reporting.continue_reporting_button")
      )
    end

    it "returns continue activity report on the income path" do
      allow(compliance).to receive(:show_income_summary).and_return(true)
      expect(helper.member_compliance_reporting_continue_button_label(compliance)).to eq(
        I18n.t("dashboard.member_compliance.reporting.continue_button")
      )
    end
  end

  describe "#show_member_compliance_activity_report_actions?" do
    let(:activity_report) { build_stubbed(:activity_report_application_form) }

    it "is true for an unsubmitted report while status is in progress" do
      allow(compliance).to receive(:report_status_token).and_return(MemberStatus::DASHBOARD_REPORT_IN_PROGRESS)
      allow(activity_report).to receive(:submitted?).and_return(false)

      expect(helper.show_member_compliance_activity_report_actions?(compliance, activity_report:)).to be true
    end

    it "is true for an unsubmitted report while status is not compliant (below threshold) and the period is open" do
      allow(compliance).to receive_messages(
        report_status_token: MemberStatus::DASHBOARD_REPORT_NOT_COMPLIANT,
        due_date: 1.month.from_now.to_date
      )
      allow(activity_report).to receive(:submitted?).and_return(false)

      expect(helper.show_member_compliance_activity_report_actions?(compliance, activity_report:)).to be true
    end

    it "is false after the reporting due date even when status is not compliant" do
      allow(compliance).to receive_messages(
        report_status_token: MemberStatus::DASHBOARD_REPORT_NOT_COMPLIANT,
        due_date: 1.day.ago.to_date
      )
      allow(activity_report).to receive(:submitted?).and_return(false)

      expect(helper.show_member_compliance_activity_report_actions?(compliance, activity_report:)).to be false
    end

    it "is false when the report is submitted (under review)" do
      allow(compliance).to receive(:report_status_token).and_return(MemberStatus::DASHBOARD_REPORT_UNDER_REVIEW)
      allow(activity_report).to receive(:submitted?).and_return(true)

      expect(helper.show_member_compliance_activity_report_actions?(compliance, activity_report:)).to be false
    end

    it "is false without an activity report form" do
      allow(compliance).to receive(:report_status_token).and_return(MemberStatus::DASHBOARD_REPORT_IN_PROGRESS)

      expect(helper.show_member_compliance_activity_report_actions?(compliance, activity_report: nil)).to be false
    end
  end
end
