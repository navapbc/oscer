# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberDashboardComplianceService do
  before do
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(HoursComplianceDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  def create_external_income_for(certification:, gross_income:, **attrs)
    lookback = certification.certification_requirements.continuous_lookback_period
    period_start = lookback.start.to_date
    period_end = lookback.start.to_date.end_of_month

    create(:external_income_activity, member_id: certification.member_id,
           period_start: period_start, period_end: period_end, gross_income: gross_income, **attrs)
  end

  describe ".build" do
    subject(:read_model) do
      described_class.build(
        certification: certification,
        certification_case: certification_case,
        exemption_application_form: exemption_application_form,
        member_status: member_status
      )
    end

    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification_id: certification.id) }
    let(:exemption_application_form) { nil }
    let(:member_status) { MemberStatusService.determine(certification) }


    context "with partial income progress" do
      before do
        create_external_income_for(certification:, gross_income: 290)
      end

      it "computes totals, remainder, percent, and deadlines from requirements" do
        expect(read_model.total_income).to eq(BigDecimal("290"))
        expect(read_model.target_income).to eq(IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY)
        expect(read_model.income_needed).to eq(BigDecimal("290"))
        expect(read_model.income_percent_of_requirement).to eq(50.0)
        expect(read_model.due_date).to eq(certification.certification_requirements.due_date)
        expect(read_model.certification_date).to eq(certification.certification_requirements.certification_date)
      end

      it "defers income aggregation until an income field is read (lazy)" do
        allow(ExternalIncomeActivity).to receive(:for_member).and_call_original
        allow(IncomeComplianceDeterminationService).to receive(:aggregate_income_for_certification).and_call_original

        rm = read_model

        # +build+ alone must not touch income — show_income_summary is true here so this proves laziness.
        expect(ExternalIncomeActivity).not_to have_received(:for_member)
        expect(IncomeComplianceDeterminationService).not_to have_received(:aggregate_income_for_certification)

        rm.total_income

        expect(ExternalIncomeActivity).to have_received(:for_member)
        expect(IncomeComplianceDeterminationService).to have_received(:aggregate_income_for_certification)
      end

      it "memoizes income computation across multiple reads" do
        allow(IncomeComplianceDeterminationService).to receive(:aggregate_income_for_certification).and_call_original

        rm = read_model
        rm.total_income
        rm.income_needed
        rm.member_income_rows

        expect(IncomeComplianceDeterminationService).to have_received(:aggregate_income_for_certification).once
      end
    end

    context "when latest determination is external_ce_combined" do
      before do
        create_external_income_for(certification:, gross_income: 100)
        create(:determination,
               subject: certification,
               outcome: "compliant",
               decision_method: "automated",
               reasons: [ "income_reported_compliant", "hours_reported_compliant" ],
               determination_data: {
                 "calculation_type" => Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED,
                 "satisfied_by" => Determination::SATISFIED_BY_BOTH
               })
      end

      let(:member_status) { MemberStatusService.determine(certification) }

      it "surfaces income summary and preserves satisfied_by on the latest determination" do
        expect(read_model.show_income_summary).to be true
        expect(read_model.total_income).to be_a(BigDecimal)
        expect(read_model.latest_determination.determination_data["satisfied_by"]).to eq(Determination::SATISFIED_BY_BOTH)
      end
    end

    context "when latest determination is hours_based" do
      before do
        create(:determination,
               subject: certification,
               outcome: "compliant",
               decision_method: "automated",
               reasons: [ "hours_reported_compliant" ],
               determination_data: { "calculation_type" => Determination::CALCULATION_TYPE_HOURS_BASED })
      end

      let(:member_status) { MemberStatusService.determine(certification) }

      it "does not surface income summary for the hours-emphasis branch" do
        expect(read_model.show_income_summary).to be false
        expect(read_model.ce_calculation_type).to eq(Determination::CALCULATION_TYPE_HOURS_BASED)
      end

      it "nils every income-scoped scalar so consumers must gate on show_income_summary" do
        expect(read_model.total_income).to be_nil
        expect(read_model.target_income).to be_nil
        expect(read_model.income_needed).to be_nil
        expect(read_model.income_percent_of_requirement).to be_nil
        expect(read_model.income_summary).to be_nil
        expect(read_model.member_income_rows).to eq([])
        expect(read_model.period_start_on).to be_nil
        expect(read_model.period_end_on).to be_nil
      end

      it "does not query ExternalIncomeActivity when income is hidden" do
        allow(ExternalIncomeActivity).to receive(:for_member).and_call_original
        allow(IncomeComplianceDeterminationService).to receive(:member_income_activities_for_certification).and_call_original
        allow(IncomeComplianceDeterminationService).to receive(:aggregate_income_for_certification).and_call_original

        read_model

        expect(ExternalIncomeActivity).not_to have_received(:for_member)
        expect(IncomeComplianceDeterminationService).not_to have_received(:member_income_activities_for_certification)
        expect(IncomeComplianceDeterminationService).not_to have_received(:aggregate_income_for_certification)
      end
    end

    context "when member status is exempt" do
      before do
        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "automated",
               reasons: [ "age_under_19_exempt" ])
      end

      let(:member_status) { MemberStatusService.determine(certification) }

      it "hides income summary cards" do
        expect(read_model.show_income_summary).to be false
      end

      it "nils every income-scoped scalar so consumers must gate on show_income_summary" do
        expect(read_model.total_income).to be_nil
        expect(read_model.target_income).to be_nil
        expect(read_model.income_needed).to be_nil
        expect(read_model.income_percent_of_requirement).to be_nil
        expect(read_model.income_summary).to be_nil
        expect(read_model.member_income_rows).to eq([])
      end

      it "marks exemption flow as approved without a form" do
        expect(read_model.exemption_flow_state).to eq(MemberDashboardCompliance::EXEMPTION_APPROVED)
      end

      it "includes automated exempt determination in exemption history" do
        expect(read_model.exemption_history.size).to eq(1)
        expect(read_model.exemption_history.first.exemption_type_key).to eq("age_under_19_exempt")
        expect(read_model.exemption_history.first.status_token).to eq(MemberDashboardCompliance::EXEMPTION_APPROVED)
      end

      it "does not query ExternalIncomeActivity when income is hidden" do
        allow(ExternalIncomeActivity).to receive(:for_member).and_call_original

        read_model

        expect(ExternalIncomeActivity).not_to have_received(:for_member)
      end
    end

    context "when continuous_lookback_period is nil" do
      before do
        allow(certification.certification_requirements)
          .to receive(:continuous_lookback_period).and_return(nil)
        create(
          :external_hourly_activity,
          member_id: certification.member_id,
          hours: 500,
          period_start: 10.years.ago.to_date,
          period_end: 10.years.ago.to_date.end_of_month
        )
      end

      it "skips income aggregation and surfaces nil income scalars" do
        allow(ExternalIncomeActivity).to receive(:for_member).and_call_original

        expect(read_model.show_income_summary).to be false
        expect(read_model.total_income).to be_nil
        expect(read_model.income_summary).to be_nil
        expect(ExternalIncomeActivity).not_to have_received(:for_member)
      end

      it "does not count external hourly rows outside a lookback window" do
        expect(read_model.total_hours_reported).to eq(0)
        expect(read_model.hours_needed).to eq(HoursComplianceDeterminationService::TARGET_HOURS)
      end
    end

    context "when an exemption is submitted and awaiting review" do
      let(:exemption_application_form) { create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

      it "exposes pending_review flow and exactly one history entry" do
        expect(read_model.exemption_flow_state).to eq(MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW)
        expect(read_model.exemption_history.size).to eq(1)
        expect(read_model.exemption_history.first.status_token).to eq(MemberDashboardCompliance::EXEMPTION_PENDING_REVIEW)
      end
    end

    context "when an approved exemption has both a determination and a submitted form" do
      let(:exemption_application_form) { create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

      before do
        certification_case.update!(exemption_request_approval_status: "approved")
        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "manual",
               reasons: [ "exemption_request_compliant" ],
               determination_data: { "exemption_type" => exemption_application_form.exemption_type },
               determined_at: 1.hour.ago)
      end

      it "emits a single approved history entry (determination is canonical)" do
        expect(read_model.exemption_history.size).to eq(1)
        expect(read_model.exemption_history.first.status_token).to eq(MemberDashboardCompliance::EXEMPTION_APPROVED)
      end
    end

    context "when staff have approved an exemption via Determination" do
      let(:exemption_application_form) { create(:exemption_application_form, certification_case_id: certification_case.id) }

      before do
        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "manual",
               reasons: [ "exemption_request_compliant" ],
               determination_data: { "exemption_type" => "short_term_hardship" },
               determined_at: 2.days.ago)
      end

      it "includes staff exemption-approved history keyed by exemption type" do
        keys = read_model.exemption_history.map(&:exemption_type_key)
        expect(keys).to include("short_term_hardship")
        expect(read_model.exemption_history.map(&:status_token)).to include(MemberDashboardCompliance::EXEMPTION_APPROVED)
      end
    end

    context "with a real locale-keyed exemption type in history" do
      let(:exemption_application_form) { create(:exemption_application_form, certification_case_id: certification_case.id) }

      before do
        create(:determination,
               subject: certification,
               outcome: "exempt",
               decision_method: "manual",
               reasons: [ "exemption_request_compliant" ],
               determination_data: { "exemption_type" => "medical_condition" },
               determined_at: 2.days.ago)
      end

      it "resolves the nested .title leaf, not the parent hash" do
        entry = read_model.exemption_history.find { |e| e.exemption_type_key == "medical_condition" }
        expect(entry).to be_present
        expect(entry.exemption_type_label).to eq(I18n.t("exemption_types.medical_condition.title"))
        expect(entry.exemption_type_label).to be_a(String)
      end
    end

    context "with employer metadata on external income rows" do
      before do
        create_external_income_for(
          certification:,
          gross_income: 100,
          metadata: { "employer" => "Secret Employer LLC" }
        )
      end

      it "does not echo employer metadata in row descriptors" do
        descriptor = read_model.member_income_rows.first.descriptor
        expect(descriptor).not_to include("Secret Employer")
      end
    end

    context "when hours aggregation runs against the open case" do
      before do
        form = create(:activity_report_application_form, certification_case_id: certification_case.id)
        create(:hourly_activity, activity_report_application_form_id: form.id, hours: 30.0)
      end

      it "includes member-reported hours in the summary (aligned with staff case lookups)" do
        expect(read_model.total_hours_reported).to eq(30)
      end
    end
  end
end
