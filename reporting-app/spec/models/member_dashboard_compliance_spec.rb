# frozen_string_literal: true

require "rails_helper"
require "support/query_count_matchers"

# Focused on the OSCER-642 data-driven activity-table inputs. The gated income/hours
# *card* readers are covered by spec/services/member_dashboard_compliance_service_spec.rb.
RSpec.describe MemberDashboardCompliance do
  subject(:read_model) do
    MemberDashboardComplianceService.build(
      certification: certification,
      certification_case: certification_case,
      activity_report_application_form: activity_report_application_form,
      exemption_application_form: exemption_application_form,
      member_status: member_status
    )
  end

  before do
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  let(:certification) { create(:certification) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }
  let(:activity_report_application_form) { nil }
  let(:exemption_application_form) { nil }
  let(:member_status) { MemberStatusService.determine(certification) }

  let(:lookback) { certification.certification_requirements.continuous_lookback_period }

  def capture_sql
    queries = []
    counter = lambda do |_name, _started, _finished, _unique_id, payload|
      unless payload[:name] == "SCHEMA" || payload[:sql] =~ /^(BEGIN|COMMIT|SAVEPOINT|RELEASE)/
        queries << payload[:sql]
      end
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    queries
  end

  def create_external_hourly(hours:, category: "employment")
    create(:external_hourly_activity,
           member_id: certification.member_id,
           category: category,
           hours: hours,
           period_start: lookback.start.to_date,
           period_end: lookback.start.to_date.end_of_month)
  end

  def create_external_income(gross_income:, category: "employment", **attrs)
    create(:external_income_activity,
           member_id: certification.member_id,
           category: category,
           gross_income: gross_income,
           period_start: lookback.start.to_date,
           period_end: lookback.start.to_date.end_of_month,
           **attrs)
  end

  describe "#hours_has_data? / #income_has_data?" do
    context "with no reported activity" do
      it "reports no data for either table" do
        expect(read_model.hours_has_data?).to be false
        expect(read_model.income_has_data?).to be false
      end
    end

    context "with only external hourly activity" do
      before { create_external_hourly(hours: 30) }

      it "has hours data but no income data" do
        expect(read_model.hours_has_data?).to be true
        expect(read_model.income_has_data?).to be false
      end
    end

    context "with only external income activity" do
      before { create_external_income(gross_income: 300) }

      it "has income data but no hours data" do
        expect(read_model.hours_has_data?).to be false
        expect(read_model.income_has_data?).to be true
      end
    end

    context "with both hourly and income activity" do
      before do
        create_external_hourly(hours: 30)
        create_external_income(gross_income: 300)
      end

      it "reports data for both tables" do
        expect(read_model.hours_has_data?).to be true
        expect(read_model.income_has_data?).to be true
      end
    end

    context "when a determination hides the income summary (hours-based)" do
      before do
        create_external_income(gross_income: 300)
        create(:determination,
               subject: certification,
               outcome: "compliant",
               decision_method: "automated",
               reasons: [ "hours_reported_compliant" ],
               determination_data: { "calculation_type" => Determination::CALCULATION_TYPE_HOURS_BASED })
      end

      it "still surfaces income table data (tables are not gated on show_income_summary)" do
        expect(read_model.show_income_summary).to be false
        expect(read_model.income_has_data?).to be true
      end
    end
  end

  describe "#hour_table_rows" do
    before { create_external_hourly(hours: 40, category: "employment") }

    let(:activity_report_application_form) do
      form = create(:activity_report_application_form, certification_case_id: certification_case.id)
      create(:hourly_activity, activity_report_application_form_id: form.id, name: "Acme Co",
             category: "employment", hours: 12, month: lookback.start.to_date)
      form
    end

    it "lists external rows first, then self-reported rows, with source tokens" do
      rows = read_model.hour_table_rows

      expect(rows.size).to eq(2)
      expect(rows.first.source_token).to eq(MemberDashboardCompliance::SOURCE_EXTERNAL_CE)
      expect(rows.first.organization_name).to include("Employment")
      expect(rows.last.source_token).to eq(MemberDashboardCompliance::SOURCE_SELF_REPORTED)
      expect(rows.last.organization_name).to eq("Acme Co")
      expect(rows.last.hours).to eq(12)
    end

    it "sums displayed hour rows for the table footer total" do
      expect(read_model.hour_table_total).to eq(52) # 40 external + 12 self-reported
    end
  end

  describe "#income_table_rows and footer totals" do
    before do
      create_external_income(gross_income: 200, metadata: { "employer" => "Globex" })
    end

    let(:activity_report_application_form) do
      form = create(:activity_report_application_form, certification_case_id: certification_case.id)
      create(:income_activity, activity_report_application_form_id: form.id, name: "Side gig",
             category: "employment", income: 15_000, month: lookback.start.to_date)
      form
    end

    it "uses employer metadata for the external org name and activity name for self-reported" do
      rows = read_model.income_table_rows

      expect(rows.first.organization_name).to eq("Globex")
      expect(rows.last.organization_name).to eq("Side gig")
    end

    it "sums reported income and derives the additional needed against the monthly target" do
      expect(read_model.income_table_total).to eq(BigDecimal("350")) # 200 external + 150 self-reported
      expect(read_model.income_table_target).to eq(IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY.to_d)
      expect(read_model.income_table_additional_needed)
        .to eq([ read_model.income_table_target - BigDecimal("350"), BigDecimal("0") ].max)
    end
  end

  describe "#activity_reports_for_line_items and #activity_line_items? (OSCER-690)" do
    # A case only permits one in-progress form at a time, so the older form is submitted before
    # the newer one is created. Events are stubbed to a no-op so submitting does not spin up a
    # pending review task that would block the second form (mirrors certification_cases_spec).
    def create_form_with_activity(name:, submitted: false)
      traits = submitted ? [ :with_submitted_status ] : []
      form = create(:activity_report_application_form, *traits, certification_case_id: certification_case.id)
      create(:hourly_activity, activity_report_application_form_id: form.id, name: name,
             category: "employment", hours: 12, month: lookback.start.to_date)
      form
    end

    context "with no activity report forms on the case" do
      it "returns no forms and reports no line items" do
        expect(read_model.activity_reports_for_line_items).to eq([])
        expect(read_model.activity_line_items?).to be false
      end
    end

    context "with multiple forms on the case" do
      before { allow(Strata::EventManager).to receive(:publish) }

      let!(:older_form) do
        form = create_form_with_activity(name: "Older Org", submitted: true)
        form.update_column(:created_at, 2.days.ago)
        form
      end
      let!(:newer_form) do
        form = create_form_with_activity(name: "Newer Org")
        form.update_column(:created_at, 1.day.ago)
        form
      end

      it "returns every form ordered newest first" do
        expect(read_model.activity_reports_for_line_items.map(&:id)).to eq([ newer_form.id, older_form.id ])
      end

      it "reports that line items exist" do
        expect(read_model.activity_line_items?).to be true
      end

      it "checks line-item presence without eager-loading attachments" do
        fresh_model = MemberDashboardComplianceService.build(
          certification: certification,
          certification_case: certification_case,
          activity_report_application_form: newer_form,
          exemption_application_form: nil,
          member_status: member_status
        )

        gate_result = nil
        gate_sql = capture_sql { gate_result = fresh_model.activity_line_items? }
        full_sql = capture_sql { fresh_model.activity_reports_for_line_items }

        expect(gate_result).to be true
        expect(gate_sql.first).to include("activities")
        expect(gate_sql.join).not_to include("active_storage")
        expect(full_sql.join).to include("active_storage")
      end

      it "eager-loads activities and supporting documents (no N+1 while rendering rows)" do
        forms = read_model.activity_reports_for_line_items

        expect {
          forms.each { |form| form.activities.each { |activity| activity.supporting_documents.map(&:filename) } }
        }.not_to exceed_query_limit(0)
      end
    end

    context "with a form that has no activities" do
      let!(:empty_form) { create(:activity_report_application_form, certification_case_id: certification_case.id) }

      it "returns the form but reports no line items" do
        expect(read_model.activity_reports_for_line_items.map(&:id)).to eq([ empty_form.id ])
        expect(read_model.activity_line_items?).to be false
      end
    end
  end
end
