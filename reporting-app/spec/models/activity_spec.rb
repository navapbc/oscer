# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Activity, type: :model do
  describe 'validations' do
    let(:activity) { build(:work_activity) }

    describe 'category validation' do
      it 'is invalid when category is nil' do
        activity.category = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:category]).to include("can't be blank")
      end

      context 'when category is a valid value' do
        it 'validates with employment' do
          activity.category = 'employment'
          expect(activity).to be_valid
        end

        it 'validates with education' do
          activity.category = 'education'
          expect(activity).to be_valid
        end

        it 'validates with community_service' do
          activity.category = 'community_service'
          expect(activity).to be_valid
        end
      end

      context 'when category is an invalid value' do
        it 'is invalid with an unknown category' do
          activity.category = 'invalid_category'
          expect(activity).not_to be_valid
          expect(activity.errors[:category]).to include('is not included in the list')
        end
      end
    end

    describe 'name validation' do
      it 'is invalid when name is nil' do
        activity.name = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:name]).to include("can't be blank")
      end

      it 'is valid with a name' do
        activity.name = 'Test Activity'
        expect(activity).to be_valid
      end
    end
  end

  describe "evidence source" do
    describe "EVIDENCE_SOURCES" do
      it "contains all valid evidence source values" do
        expect(Activity::EVIDENCE_SOURCES).to match_array(
          %w[self_reported ai_assisted ai_assisted_with_member_edits ai_rejected_member_override]
        )
      end
    end

    describe "AI_SOURCED_EVIDENCE_SOURCES" do
      it "contains only AI-sourced evidence source values" do
        expect(Activity::AI_SOURCED_EVIDENCE_SOURCES).to match_array(
          %w[ai_assisted ai_assisted_with_member_edits]
        )
      end

      it "is a subset of EVIDENCE_SOURCES" do
        expect(Activity::AI_SOURCED_EVIDENCE_SOURCES - Activity::EVIDENCE_SOURCES).to be_empty
      end
    end

    describe "evidence_source validation" do
      it "is valid with a recognized evidence source" do
        activity = build(:work_activity, evidence_source: "ai_assisted")
        expect(activity).to be_valid
      end

      it "is valid with nil evidence source" do
        activity = build(:work_activity, evidence_source: nil)
        expect(activity).to be_valid
      end

      it "is invalid with an unrecognized evidence source" do
        activity = build(:work_activity, evidence_source: "unknown_source")
        expect(activity).not_to be_valid
        expect(activity.errors[:evidence_source]).to include("is not included in the list")
      end
    end

    describe "#self_reported?" do
      it "returns true when evidence_source is nil" do
        activity = build(:work_activity, evidence_source: nil)
        expect(activity.self_reported?).to be true
      end

      it "returns true when evidence_source is self_reported" do
        activity = build(:work_activity, evidence_source: "self_reported")
        expect(activity.self_reported?).to be true
      end

      it "returns false for ai_assisted" do
        activity = build(:work_activity, evidence_source: "ai_assisted")
        expect(activity.self_reported?).to be false
      end
    end

    describe "#ai_sourced?" do
      it "returns true for ai_assisted" do
        activity = build(:work_activity, evidence_source: "ai_assisted")
        expect(activity.ai_sourced?).to be true
      end

      it "returns true for ai_assisted_with_member_edits" do
        activity = build(:work_activity, evidence_source: "ai_assisted_with_member_edits")
        expect(activity.ai_sourced?).to be true
      end

      it "returns false for self_reported" do
        activity = build(:work_activity, evidence_source: "self_reported")
        expect(activity.ai_sourced?).to be false
      end

      it "returns false for nil" do
        activity = build(:work_activity, evidence_source: nil)
        expect(activity.ai_sourced?).to be false
      end
    end
  end
end
