# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncomeActivity, type: :model do
  let(:activity_report_application_form) { create(:activity_report_application_form) }
  let(:income_activity) do
    create(:income_activity,
      activity_report_application_form_id: activity_report_application_form.id,
      evidence_source: "ai_assisted",
      month: Date.new(2025, 1, 1),
      income: 150_000
    )
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:income_activity, activity_report_application_form_id: activity_report_application_form.id)).to be_valid
    end

    it 'is invalid without income' do
      activity = build(:income_activity, income: nil)
      expect(activity).not_to be_valid
      expect(activity.errors[:income]).to include("must be greater than 0")
    end

    it 'is invalid with zero income' do
      activity = build(:income_activity, income: 0)
      expect(activity).not_to be_valid
      expect(activity.errors[:income]).to include("must be greater than 0")
    end

    it 'is invalid with negative income' do
      activity = build(:income_activity, income: -100)
      expect(activity).not_to be_valid
      expect(activity.errors[:income]).to include("must be greater than 0")
    end
  end

  describe "#update_with_doc_ai_review" do
    context "when evidence_source is ai_assisted" do
      it "updates attributes and keeps evidence_source if income and month are unchanged" do
        income_activity.update_with_doc_ai_review(name: "New Name")
        expect(income_activity.name).to eq("New Name")
        expect(income_activity.evidence_source).to eq("ai_assisted")
      end

      it "updates evidence_source to ai_assisted_with_member_edits if income changes" do
        income_activity.update_with_doc_ai_review(income: 200_000)
        expect(income_activity.income.cents).to eq(200_000)
        expect(income_activity.evidence_source).to eq("ai_assisted_with_member_edits")
      end

      it "updates evidence_source to ai_assisted_with_member_edits if month changes" do
        income_activity.update_with_doc_ai_review(month: Date.new(2025, 2, 1))
        expect(income_activity.month).to eq(Date.new(2025, 2, 1))
        expect(income_activity.evidence_source).to eq("ai_assisted_with_member_edits")
      end
    end

    context "when evidence_source is not ai_assisted" do
      let(:self_reported_activity) do
        create(:income_activity,
          activity_report_application_form_id: activity_report_application_form.id,
          evidence_source: "self_reported",
          income: 100_000
        )
      end

      it "does not change evidence_source even if income changes" do
        self_reported_activity.update_with_doc_ai_review(income: 200_000)
        expect(self_reported_activity.income.cents).to eq(200_000)
        expect(self_reported_activity.evidence_source).to eq("self_reported")
      end
    end
  end
end
