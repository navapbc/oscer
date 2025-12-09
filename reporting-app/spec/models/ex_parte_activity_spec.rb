# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExParteActivity, type: :model do
  describe "factory" do
    it "creates a valid record" do
      activity = build(:ex_parte_activity)
      expect(activity).to be_valid
    end

    it "creates a valid pending record" do
      activity = build(:ex_parte_activity, :pending)
      expect(activity).to be_valid
      expect(activity.certification_id).to be_nil
    end
  end

  describe "validations" do
    subject(:activity) { build(:ex_parte_activity) }

    describe "member_id" do
      it "is required" do
        activity.member_id = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:member_id]).to include("can't be blank")
      end
    end

    describe "category" do
      it "is required" do
        activity.category = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:category]).to include("can't be blank")
      end

      it "accepts valid categories" do
        ExParteActivity::ALLOWED_CATEGORIES.each do |category|
          activity.category = category
          expect(activity).to be_valid
        end
      end

      it "rejects invalid categories" do
        activity.category = "invalid_category"
        expect(activity).not_to be_valid
        expect(activity.errors[:category]).to include("is not included in the list")
      end
    end

    describe "hours" do
      it "is required" do
        activity.hours = nil
        expect(activity).not_to be_valid
        expect(activity.errors[:hours]).to include("can't be blank")
      end

      it "must be greater than 0" do
        activity.hours = 0
        expect(activity).not_to be_valid
        expect(activity.errors[:hours]).to include("must be greater than 0")
      end

      it "must be less than or equal to MAX_HOURS" do
        activity.hours = ExParteActivity::MAX_HOURS + 1
        expect(activity).not_to be_valid
      end

      it "accepts valid hours" do
        activity.hours = 40.5
        expect(activity).to be_valid
      end
    end

    describe "period dates" do
      it "requires period_start" do
        activity.period_start = nil
        expect(activity).not_to be_valid
      end

      it "requires period_end" do
        activity.period_end = nil
        expect(activity).not_to be_valid
      end

      it "rejects period_end before period_start" do
        activity.period_start = Date.new(2025, 1, 15)
        activity.period_end = Date.new(2025, 1, 1)
        expect(activity).not_to be_valid
        expect(activity.errors[:period_end]).to include("must be on or after period start")
      end

      it "accepts period_end equal to period_start" do
        activity.period_start = Date.new(2025, 1, 15)
        activity.period_end = Date.new(2025, 1, 15)
        expect(activity).to be_valid
      end
    end

    describe "source_type" do
      it "is required" do
        activity.source_type = nil
        expect(activity).not_to be_valid
      end

      it "accepts valid source types" do
        ExParteActivity::ALLOWED_SOURCE_TYPES.each do |source|
          activity.source_type = source
          expect(activity).to be_valid
        end
      end

      it "rejects invalid source types" do
        activity.source_type = "invalid"
        expect(activity).not_to be_valid
      end
    end

    describe "reported_at" do
      it "is required" do
        activity.reported_at = nil
        expect(activity).not_to be_valid
      end
    end

    describe "certification_id" do
      it "is optional" do
        activity.certification_id = nil
        expect(activity).to be_valid
      end
    end
  end

  describe "scopes" do
    let(:certification) { create(:certification) }

    describe ".for_certification" do
      it "returns entries for the given certification" do
        entry = create(:ex_parte_activity, certification: certification)
        create(:ex_parte_activity) # different certification

        expect(described_class.for_certification(certification.id)).to eq([ entry ])
      end
    end

    describe ".pending_for_member" do
      it "returns pending entries for the given member" do
        member_id = "M12345"
        pending = create(:ex_parte_activity, :pending, member_id: member_id)
        create(:ex_parte_activity, member_id: member_id, certification: certification) # linked
        create(:ex_parte_activity, :pending, member_id: "OTHER") # different member

        expect(described_class.pending_for_member(member_id)).to eq([ pending ])
      end
    end

    describe ".by_category" do
      it "returns entries for the given category" do
        employment = create(:ex_parte_activity, :employment)
        create(:ex_parte_activity, :community_service)

        expect(described_class.by_category("employment")).to eq([ employment ])
      end
    end

    describe ".in_period" do
      it "returns entries overlapping the date range" do
        within = create(:ex_parte_activity,
                        period_start: Date.new(2025, 1, 10),
                        period_end: Date.new(2025, 1, 20))
        create(:ex_parte_activity,
               period_start: Date.new(2025, 3, 1),
               period_end: Date.new(2025, 3, 31)) # outside

        result = described_class.in_period(Date.new(2025, 1, 1), Date.new(2025, 1, 31))
        expect(result).to eq([ within ])
      end
    end
  end

  describe "#pending?" do
    it "returns true when certification_id is nil" do
      activity = build(:ex_parte_activity, :pending)
      expect(activity.pending?).to be true
    end

    it "returns false when certification_id is present" do
      activity = build(:ex_parte_activity)
      expect(activity.pending?).to be false
    end
  end

  describe "#link_to_certification!" do
    it "updates the certification_id" do
      certification = create(:certification)
      activity = create(:ex_parte_activity, :pending)

      activity.link_to_certification!(certification.id)

      expect(activity.reload.certification_id).to eq(certification.id)
    end
  end

  describe "constants" do
    it "defines ALLOWED_CATEGORIES" do
      expect(ExParteActivity::ALLOWED_CATEGORIES).to eq(%w[employment community_service education])
    end

    it "defines source type constants" do
      expect(ExParteActivity::SOURCE_TYPE_API).to eq("api")
      expect(ExParteActivity::SOURCE_TYPE_BATCH).to eq("batch_upload")
    end

    it "defines MAX_HOURS" do
      expect(ExParteActivity::MAX_HOURS).to eq(744)
    end
  end
end
