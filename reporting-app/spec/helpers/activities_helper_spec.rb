# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivitiesHelper, type: :helper do
  describe "EVIDENCE_SOURCE_ICONS" do
    it "has an icon mapping for every Activity evidence source" do
      expect(ActivitiesHelper::EVIDENCE_SOURCE_ICONS.keys).to match_array(Activity::EVIDENCE_SOURCES)
    end
  end

  describe "#evidence_source_icon" do
    it "returns person icon for nil evidence source" do
      result = helper.evidence_source_icon(nil)
      expect(result[:icon]).to eq("person")
      expect(result[:color]).to eq("text-primary")
      expect(result[:label]).to eq("Self Reported")
    end

    it "returns person icon for self_reported" do
      result = helper.evidence_source_icon("self_reported")
      expect(result[:icon]).to eq("person")
      expect(result[:color]).to eq("text-primary")
      expect(result[:label]).to eq("Self Reported")
    end

    it "returns insights icon for ai_assisted" do
      result = helper.evidence_source_icon("ai_assisted")
      expect(result[:icon]).to eq("insights")
      expect(result[:color]).to eq("text-gold")
      expect(result[:label]).to eq("AI Assisted")
    end

    it "returns edit icon for ai_assisted_with_member_edits" do
      result = helper.evidence_source_icon("ai_assisted_with_member_edits")
      expect(result[:icon]).to eq("edit")
      expect(result[:color]).to eq("text-green")
      expect(result[:label]).to eq("AI Assisted with Edits")
    end

    it "returns warning icon for ai_rejected_member_override" do
      result = helper.evidence_source_icon("ai_rejected_member_override")
      expect(result[:icon]).to eq("warning")
      expect(result[:color]).to eq("text-error")
      expect(result[:label]).to eq("AI Rejected")
    end

    it "falls back to self_reported icon and label for unknown source" do
      result = helper.evidence_source_icon("unknown_source")
      expect(result[:icon]).to eq("person")
      expect(result[:color]).to eq("text-primary")
      expect(result[:label]).to eq("Self Reported")
    end
  end

  describe "ATTRIBUTION_FIELD_CLASSES" do
    it "has a class mapping for every Activity evidence source" do
      expect(ActivitiesHelper::ATTRIBUTION_FIELD_CLASSES.keys).to match_array(Activity::EVIDENCE_SOURCES)
    end
  end

  describe "#attribution_field_classes" do
    it "returns primary classes for nil evidence source" do
      result = helper.attribution_field_classes(nil)
      expect(result).to eq("bg-attribution-primary")
    end

    it "returns primary classes for self_reported" do
      result = helper.attribution_field_classes(ActivityAttributions::SELF_REPORTED)
      expect(result).to eq("bg-attribution-primary")
    end

    it "returns gold classes for ai_assisted" do
      result = helper.attribution_field_classes(ActivityAttributions::AI_ASSISTED)
      expect(result).to eq("bg-attribution-gold")
    end

    it "returns green classes for ai_assisted_with_member_edits" do
      result = helper.attribution_field_classes(ActivityAttributions::AI_ASSISTED_WITH_MEMBER_EDITS)
      expect(result).to eq("bg-attribution-green")
    end

    it "returns error classes for ai_rejected_member_override" do
      result = helper.attribution_field_classes(ActivityAttributions::AI_REJECTED_MEMBER_OVERRIDE)
      expect(result).to eq("border-1px border-error bg-attribution-error")
    end

    it "returns empty string for unknown evidence source" do
      result = helper.attribution_field_classes("unknown_source")
      expect(result).to eq("")
    end
  end

  describe "#confidence_display" do
    before do
      allow(Rails.application.config).to receive(:doc_ai).and_return({ low_confidence_threshold: 0.7 })
    end

    it "returns nil for nil input" do
      expect(helper.confidence_display(nil)).to be_nil
    end

    it "returns percentage as integer and low: false for high confidence" do
      result = helper.confidence_display(0.93)
      expect(result[:percentage]).to eq(93)
      expect(result[:low]).to be false
    end

    it "returns low: true for confidence below threshold" do
      result = helper.confidence_display(0.65)
      expect(result[:percentage]).to eq(65)
      expect(result[:low]).to be true
    end

    it "returns low: false for confidence at threshold" do
      result = helper.confidence_display(0.7)
      expect(result[:percentage]).to eq(70)
      expect(result[:low]).to be false
    end

    it "returns low: true for confidence just below threshold" do
      result = helper.confidence_display(0.69)
      expect(result[:percentage]).to eq(69)
      expect(result[:low]).to be true
    end

    it "returns low: false when confidence rounds up to threshold" do
      result = helper.confidence_display(0.695)
      expect(result[:percentage]).to eq(70)
      expect(result[:low]).to be false
    end
  end

  describe "#confidence_value_content" do
    before do
      allow(Rails.application.config).to receive(:doc_ai).and_return({ low_confidence_threshold: 0.7 })
    end

    it "returns an em-dash for nil conf" do
      result = helper.confidence_value_content(nil)
      expect(result).to eq("—")
    end

    it "returns percentage for normal confidence" do
      conf = { percentage: 85, low: false }
      result = helper.confidence_value_content(conf)
      expect(result).to include("85%")
      expect(result).not_to include("warning")
    end

    it "returns warning icon and percentage for low confidence" do
      conf = { percentage: 55, low: true }
      result = helper.confidence_value_content(conf)
      expect(result).to include("55%")
      expect(result).to include("#warning")
      expect(result).to include("Low confidence")
    end
  end

  describe "#confidence_cell_content" do
    before do
      allow(Rails.application.config).to receive(:doc_ai).and_return({ low_confidence_threshold: 0.7 })
    end

    it "returns em-dash for non-AI activity" do
      activity = build(:work_activity, evidence_source: "self_reported")
      result = helper.confidence_cell_content(activity, { activity.id => 0.91 })
      expect(result).to eq("—")
    end

    it "returns em-dash when confidence_by_activity is nil" do
      activity = build(:income_activity, evidence_source: "ai_assisted")
      result = helper.confidence_cell_content(activity, nil)
      expect(result).to eq("—")
    end

    it "returns percentage for AI activity with confidence" do
      activity = build(:income_activity, evidence_source: "ai_assisted")
      result = helper.confidence_cell_content(activity, { activity.id => 0.91 })
      expect(result).to include("91%")
    end

    it "returns em-dash for AI activity with nil confidence" do
      activity = build(:income_activity, evidence_source: "ai_assisted")
      result = helper.confidence_cell_content(activity, { activity.id => nil })
      expect(result).to eq("—")
    end
  end

  describe "#field_attributions" do
    let(:month) { Date.new(2026, 2, 1) }

    context "when activity is not AI-sourced" do
      let(:activity) { build(:income_activity, evidence_source: "self_reported", month: month, income: 150_000) }

      it "returns self_reported for all fields" do
        result = helper.field_attributions(activity, nil)

        expect(result[:category]).to eq(ActivityAttributions::SELF_REPORTED)
        expect(result[:reporting_method]).to eq(ActivityAttributions::SELF_REPORTED)
        expect(result[:name]).to eq(ActivityAttributions::SELF_REPORTED)
        expect(result[:month]).to eq(ActivityAttributions::SELF_REPORTED)
        expect(result[:income]).to eq(ActivityAttributions::SELF_REPORTED)
      end
    end

    context "when activity is AI-sourced with no staged document" do
      let(:activity) { build(:income_activity, :ai_assisted, month: month, income: 150_000) }

      it "returns self_reported for all fields" do
        result = helper.field_attributions(activity, nil)

        expect(result[:month]).to eq(ActivityAttributions::SELF_REPORTED)
        expect(result[:income]).to eq(ActivityAttributions::SELF_REPORTED)
      end
    end

    context "when IncomeActivity has unchanged AI values" do
      let(:activity) { build(:income_activity, :ai_assisted, month: month, income: 150_000) }
      let(:staged_document) do
        build(:staged_document, :validated, extracted_fields: {
          "payperiodstartdate" => { "value" => "2026-02-01", "confidence" => 0.9 },
          "currentgrosspay" => { "value" => 1500.0, "confidence" => 0.9 }
        })
      end

      it "returns ai_assisted for month and income" do
        result = helper.field_attributions(activity, staged_document)

        expect(result[:month]).to eq(ActivityAttributions::AI_ASSISTED)
        expect(result[:income]).to eq(ActivityAttributions::AI_ASSISTED)
      end

      it "returns self_reported for non-AI fields" do
        result = helper.field_attributions(activity, staged_document)

        expect(result[:category]).to eq(ActivityAttributions::SELF_REPORTED)
        expect(result[:reporting_method]).to eq(ActivityAttributions::SELF_REPORTED)
        expect(result[:name]).to eq(ActivityAttributions::SELF_REPORTED)
      end
    end

    context "when IncomeActivity has member-edited income but unchanged month" do
      let(:activity) { build(:income_activity, :ai_assisted, month: month, income: 200_000) }
      let(:staged_document) do
        build(:staged_document, :validated, extracted_fields: {
          "payperiodstartdate" => { "value" => "2026-02-01", "confidence" => 0.9 },
          "currentgrosspay" => { "value" => 1500.0, "confidence" => 0.9 }
        })
      end

      it "returns ai_assisted_with_member_edits for income" do
        result = helper.field_attributions(activity, staged_document)

        expect(result[:income]).to eq(ActivityAttributions::AI_ASSISTED_WITH_MEMBER_EDITS)
      end

      it "returns ai_assisted for month" do
        result = helper.field_attributions(activity, staged_document)

        expect(result[:month]).to eq(ActivityAttributions::AI_ASSISTED)
      end
    end

    context "when IncomeActivity has member-edited month but unchanged income" do
      let(:activity) { build(:income_activity, :ai_assisted, month: Date.new(2026, 3, 1), income: 150_000) }
      let(:staged_document) do
        build(:staged_document, :validated, extracted_fields: {
          "payperiodstartdate" => { "value" => "2026-02-15", "confidence" => 0.9 },
          "currentgrosspay" => { "value" => 1500.0, "confidence" => 0.9 }
        })
      end

      it "returns ai_assisted_with_member_edits for month" do
        result = helper.field_attributions(activity, staged_document)

        expect(result[:month]).to eq(ActivityAttributions::AI_ASSISTED_WITH_MEMBER_EDITS)
      end

      it "returns ai_assisted for income" do
        result = helper.field_attributions(activity, staged_document)

        expect(result[:income]).to eq(ActivityAttributions::AI_ASSISTED)
      end
    end

    context "when activity is an AI-sourced HourlyActivity" do
      let(:activity) { build(:hourly_activity, :ai_assisted, month: month, hours: 40) }
      let(:staged_document) do
        build(:staged_document, :validated, extracted_fields: {
          "payperiodstartdate" => { "value" => "2026-02-01", "confidence" => 0.9 },
          "currentgrosspay" => { "value" => 1500.0, "confidence" => 0.9 }
        })
      end

      it "returns self_reported for hours since AI never extracts hours" do
        result = helper.field_attributions(activity, staged_document)

        expect(result[:hours]).to eq(ActivityAttributions::SELF_REPORTED)
      end

      it "returns ai_assisted for month" do
        result = helper.field_attributions(activity, staged_document)

        expect(result[:month]).to eq(ActivityAttributions::AI_ASSISTED)
      end
    end
  end

  describe "#attribution_locals_for" do
    it "returns field_classes, icon_info, and attribution_label for a given evidence source" do
      result = helper.attribution_locals_for(ActivityAttributions::AI_ASSISTED)

      expect(result[:field_classes]).to eq("bg-attribution-gold")
      expect(result[:icon_info][:icon]).to eq("insights")
      expect(result[:attribution_label]).to eq("AI Assisted")
    end

    it "returns self_reported locals for nil" do
      result = helper.attribution_locals_for(nil)

      expect(result[:field_classes]).to eq("bg-attribution-primary")
      expect(result[:attribution_label]).to eq("Self Reported")
    end
  end

  describe "#task_confidence" do
    before do
      allow(Rails.application.config).to receive(:doc_ai).and_return({ low_confidence_threshold: 0.7 })
    end

    it "returns nil conf when confidence_by_case is nil" do
      result = helper.task_confidence("case-123", nil)
      expect(result[:conf]).to be_nil
      expect(result[:low]).to be false
    end

    it "returns conf hash for a case with confidence data" do
      result = helper.task_confidence("case-123", { "case-123" => 0.85 })
      expect(result[:conf][:percentage]).to eq(85)
      expect(result[:low]).to be false
    end

    it "returns low: true for low confidence case" do
      result = helper.task_confidence("case-123", { "case-123" => 0.55 })
      expect(result[:conf][:percentage]).to eq(55)
      expect(result[:low]).to be true
    end

    it "returns nil conf when case_id is not in the confidence hash" do
      result = helper.task_confidence("case-999", { "case-123" => 0.85 })
      expect(result[:conf]).to be_nil
      expect(result[:low]).to be false
    end
  end
end
