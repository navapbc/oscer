# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayslipToIncomeActivityCreateService do
  let(:user) { create(:user) }
  let(:form) do
    create(
      :activity_report_application_form,
      user_id: user.id,
      reporting_periods: [
        Strata::YearMonth.new(year: 2025, month: 1),
        Strata::YearMonth.new(year: 2025, month: 2)
      ]
    )
  end
  let(:service) { described_class.new(form: form) }

  def create_staged_document(traits: [ :validated ], overrides: {})
    create(:staged_document, *traits, user_id: user.id, **overrides)
  end

  describe "#call" do
    context "with a validated Payslip document" do
      let(:staged_doc) do
        create_staged_document(
          overrides: {
            extracted_fields: {
              "currentgrosspay" => { "confidence" => 0.93, "value" => 1500.0 },
              "payperiodstartdate" => { "confidence" => 0.95, "value" => "2025-01-15" }
            }
          }
        )
      end

      it "creates an IncomeActivity" do
        expect {
          service.call([ staged_doc.id ])
        }.to change(IncomeActivity, :count).by(1)
      end

      it "sets income from current_gross_pay converted to cents" do
        activities = service.call([ staged_doc.id ])
        expect(activities.first.income).to eq(Strata::Money.new(cents: 150_000))
      end

      it "leaves name blank" do
        activities = service.call([ staged_doc.id ])
        expect(activities.first.name).to be_nil
      end

      it "derives month from pay_period_start_date matching reporting period" do
        activities = service.call([ staged_doc.id ])
        expect(activities.first.month).to eq(Date.new(2025, 1, 1))
      end

      it "sets category to employment" do
        activities = service.call([ staged_doc.id ])
        expect(activities.first.category).to eq("employment")
      end

      it "sets evidence_source to ai_assisted" do
        activities = service.call([ staged_doc.id ])
        expect(activities.first.evidence_source).to eq(ActivityAttributions::AI_ASSISTED)
      end

      it "attaches the original file blob as a supporting document" do
        activities = service.call([ staged_doc.id ])
        fresh_activity = Activity.find(activities.first.id)
        expect(fresh_activity.supporting_documents.count).to eq(1)
      end

      it "sets stageable on the StagedDocument" do
        activities = service.call([ staged_doc.id ])
        staged_doc.reload
        expect(staged_doc.stageable_id).to eq(activities.first.id)
        expect(staged_doc.stageable_type).to eq("Activity")
      end
    end

    context "with multiple validated Payslip documents" do
      let(:first_staged_doc) do
        create_staged_document(
          overrides: {
            extracted_fields: {
              "currentgrosspay" => { "confidence" => 0.93, "value" => 1500.0 },
              "payperiodstartdate" => { "confidence" => 0.95, "value" => "2025-01-15" }
            }
          }
        )
      end
      let(:second_staged_doc) do
        create_staged_document(
          overrides: {
            extracted_fields: {
              "currentgrosspay" => { "confidence" => 0.90, "value" => 2000.0 },
              "payperiodstartdate" => { "confidence" => 0.88, "value" => "2025-02-10" }
            }
          }
        )
      end

      it "creates an IncomeActivity for each document" do
        expect {
          service.call([ first_staged_doc.id, second_staged_doc.id ])
        }.to change(IncomeActivity, :count).by(2)
      end
    end

    context "with ineligible documents" do
      let(:rejected_doc) { create_staged_document(traits: [ :rejected ]) }
      let(:failed_doc) { create_staged_document(traits: [ :failed ]) }
      let(:w2_doc) do
        create_staged_document(
          overrides: {
            status: "validated",
            doc_ai_matched_class: "W2",
            extracted_fields: { "wages" => { "confidence" => 0.9, "value" => 50_000 } }
          }
        )
      end
      let(:already_assigned_doc) do
        activity = create(:income_activity, activity_report_application_form_id: form.id)
        create_staged_document(
          overrides: {
            stageable: activity,
            extracted_fields: {
              "currentgrosspay" => { "confidence" => 0.93, "value" => 1500.0 }
            }
          }
        )
      end

      it "skips rejected documents" do
        expect {
          service.call([ rejected_doc.id ])
        }.not_to change(IncomeActivity, :count)
      end

      it "skips failed documents" do
        expect {
          service.call([ failed_doc.id ])
        }.not_to change(IncomeActivity, :count)
      end

      it "skips non-Payslip documents" do
        expect {
          service.call([ w2_doc.id ])
        }.not_to change(IncomeActivity, :count)
      end

      it "skips already-assigned documents" do
        already_assigned_doc # force evaluation before count snapshot
        expect {
          service.call([ already_assigned_doc.id ])
        }.not_to change(IncomeActivity, :count)
      end

      it "returns an empty array when no eligible documents" do
        result = service.call([ rejected_doc.id, failed_doc.id ])
        expect(result).to eq([])
      end
    end

    context "with month derivation edge cases" do
      it "raises PayslipNotInReportingPeriodError when pay date is outside reporting periods" do
        doc = create_staged_document(
          overrides: {
            extracted_fields: {
              "currentgrosspay" => { "confidence" => 0.93, "value" => 1000.0 },
              "payperiodstartdate" => { "confidence" => 0.95, "value" => "2024-06-15" }
            }
          }
        )
        expect {
          service.call([ doc.id ])
        }.to raise_error(PayslipToIncomeActivityCreateService::PayslipNotInReportingPeriodError)
      end

      it "raises PayslipNotInReportingPeriodError when pay_period_start_date is missing" do
        doc = create_staged_document(
          overrides: {
            extracted_fields: {
              "currentgrosspay" => { "confidence" => 0.93, "value" => 1000.0 }
            }
          }
        )
        expect {
          service.call([ doc.id ])
        }.to raise_error(PayslipToIncomeActivityCreateService::PayslipNotInReportingPeriodError)
      end
    end

    context "with nil/missing fields" do
      it "sets income to nil when current_gross_pay is missing" do
        doc = create_staged_document(
          overrides: {
            extracted_fields: {
              "payperiodstartdate" => { "confidence" => 0.95, "value" => "2025-01-15" }
            }
          }
        )
        activities = service.call([ doc.id ])
        expect(activities.first.income).to be_nil
      end
    end
  end
end
