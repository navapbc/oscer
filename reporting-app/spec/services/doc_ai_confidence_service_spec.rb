# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocAiConfidenceService do
  let(:service) { described_class.new }

  describe "#confidence_for_activity" do
    context "when activity is not ai_sourced" do
      let(:activity) { build(:work_activity, evidence_source: "self_reported") }

      it "returns nil" do
        expect(service.confidence_for_activity(activity)).to be_nil
      end
    end

    context "when activity is ai_sourced with no validated staged documents" do
      let(:form) { create(:activity_report_application_form) }
      let(:activity) { create(:work_activity, evidence_source: "ai_assisted", activity_report_application_form_id: form.id) }

      it "returns nil" do
        expect(service.confidence_for_activity(activity)).to be_nil
      end
    end

    context "when activity is ai_sourced with validated staged documents" do
      let(:user) { create(:user) }
      let(:form) { create(:activity_report_application_form) }
      let(:activity) { create(:work_activity, evidence_source: "ai_assisted", activity_report_application_form_id: form.id) }

      before do
        create(:staged_document, :validated,
          stageable: activity,
          user_id: user.id,
          extracted_fields: {
            "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 },
            "payperiod" => { "confidence" => 0.87, "value" => "2024-01-15" }
          })
      end

      it "returns average confidence from validated documents" do
        expect(service.confidence_for_activity(activity)).to eq(0.90)
      end
    end

    context "when activity is ai_assisted_with_member_edits" do
      let(:user) { create(:user) }
      let(:form) { create(:activity_report_application_form) }
      let(:activity) { create(:work_activity, evidence_source: "ai_assisted_with_member_edits", activity_report_application_form_id: form.id) }

      before do
        create(:staged_document, :validated,
          stageable: activity,
          user_id: user.id,
          extracted_fields: { "grosspay" => { "confidence" => 0.88, "value" => 2000 } })
      end

      it "returns confidence for edited AI activity" do
        expect(service.confidence_for_activity(activity)).to eq(0.88)
      end
    end

    context "when activity has multiple validated staged documents" do
      let(:user) { create(:user) }
      let(:form) { create(:activity_report_application_form) }
      let(:activity) { create(:work_activity, evidence_source: "ai_assisted", activity_report_application_form_id: form.id) }

      before do
        create(:staged_document, :validated,
          stageable: activity,
          user_id: user.id,
          extracted_fields: { "grosspay" => { "confidence" => 0.95, "value" => 1000 } })
        create(:staged_document, :validated,
          stageable: activity,
          user_id: user.id,
          extracted_fields: { "grosspay" => { "confidence" => 0.85, "value" => 2000 } })
      end

      it "returns average across all documents" do
        expect(service.confidence_for_activity(activity)).to eq(0.90)
      end
    end
  end

  describe "#confidence_by_case_id" do
    let(:user) { create(:user) }
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }
    let(:form) { create(:activity_report_application_form, certification_case_id: certification_case.id) }

    context "with no activities" do
      it "returns nil for the case" do
        form
        result = service.confidence_by_case_id([ certification_case.id ])
        expect(result[certification_case.id]).to be_nil
      end
    end

    context "with ai_sourced activities and validated documents" do
      before do
        activity = form.activities.create!(
          name: "Test Co",
          type: "WorkActivity",
          hours: 40,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "ai_assisted"
        )
        create(:staged_document, :validated,
          stageable: activity,
          user_id: user.id,
          extracted_fields: {
            "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 }
          })
      end

      it "returns confidence for the case" do
        result = service.confidence_by_case_id([ certification_case.id ])
        expect(result[certification_case.id]).to eq(0.93)
      end
    end

    context "with ai_assisted_with_member_edits activities" do
      before do
        activity = form.activities.create!(
          name: "Edited Co",
          type: "WorkActivity",
          hours: 30,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "ai_assisted_with_member_edits"
        )
        create(:staged_document, :validated,
          stageable: activity,
          user_id: user.id,
          extracted_fields: {
            "currentgrosspay" => { "confidence" => 0.88, "value" => 2000 }
          })
      end

      it "returns confidence for the case" do
        result = service.confidence_by_case_id([ certification_case.id ])
        expect(result[certification_case.id]).to eq(0.88)
      end
    end

    context "with ai_sourced activities but no validated staged documents" do
      before do
        form.activities.create!(
          name: "No Docs Co",
          type: "WorkActivity",
          hours: 20,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "ai_assisted"
        )
      end

      it "returns nil for the case" do
        result = service.confidence_by_case_id([ certification_case.id ])
        expect(result[certification_case.id]).to be_nil
      end
    end

    context "with multiple cases" do
      let(:certification2) { create(:certification) }
      let(:case2) { create(:certification_case, certification: certification2) }
      let(:form2) { create(:activity_report_application_form, certification_case_id: case2.id) }

      before do
        activity1 = form.activities.create!(
          name: "Co A",
          type: "WorkActivity",
          hours: 40,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "ai_assisted"
        )
        create(:staged_document, :validated,
          stageable: activity1,
          user_id: user.id,
          extracted_fields: { "grosspay" => { "confidence" => 0.95, "value" => 1000 } })

        activity2 = form2.activities.create!(
          name: "Co B",
          type: "WorkActivity",
          hours: 20,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "ai_assisted"
        )
        create(:staged_document, :validated,
          stageable: activity2,
          user_id: user.id,
          extracted_fields: { "grosspay" => { "confidence" => 0.60, "value" => 500 } })
      end

      it "returns correct confidence per case without bleed" do
        result = service.confidence_by_case_id([ certification_case.id, case2.id ])
        expect(result[certification_case.id]).to eq(0.95)
        expect(result[case2.id]).to eq(0.60)
      end
    end

    context "with only self_reported activities" do
      before do
        form.activities.create!(
          name: "Test Co",
          type: "WorkActivity",
          hours: 40,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "self_reported"
        )
      end

      it "returns nil for the case" do
        result = service.confidence_by_case_id([ certification_case.id ])
        expect(result[certification_case.id]).to be_nil
      end
    end

    context "with empty case_ids" do
      it "returns empty hash" do
        expect(service.confidence_by_case_id([])).to eq({})
      end
    end
  end
end
