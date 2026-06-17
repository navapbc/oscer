# frozen_string_literal: true

require "rails_helper"

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
end
