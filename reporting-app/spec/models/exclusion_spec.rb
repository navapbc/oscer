# frozen_string_literal: true

require "rails_helper"

RSpec.describe Exclusion, type: :model do
  # The spec's default priority order (high durability -> low).
  let(:priority_ordered_ids) do
    %i[
      is_american_indian_or_alaska_native
      former_foster_care
      is_veteran_with_disability
      medically_frail
      caretaker
      tanf_snap_work
      drug_treatment
      is_pregnant
      inmate
    ]
  end

  describe ".all" do
    it "returns all 9 exclusion types" do
      expect(described_class.all.size).to eq(9)
    end

    it "is sorted ascending by :priority (highest durability first)" do
      expect(described_class.all.map { |t| t[:id] }).to eq(priority_ordered_ids)
    end

    context "when the config is declared out of priority order" do
      before do
        allow(Rails.application.config).to receive(:exclusion_types).and_return(
          [
            { id: :is_pregnant, priority: 80 },
            { id: :is_american_indian_or_alaska_native, priority: 10 },
            { id: :is_veteran_with_disability, priority: 30 }
          ]
        )
      end

      it "returns entries sorted ascending by :priority" do
        expect(described_class.all.map { |t| t[:id] }).to eq(
          %i[is_american_indian_or_alaska_native is_veteran_with_disability is_pregnant]
        )
      end
    end
  end

  describe ".priority_order" do
    it "returns all exclusion ids in priority order (high to low)" do
      expect(described_class.priority_order).to eq(priority_ordered_ids)
    end
  end

  describe ".valid_values" do
    it "returns the 9 exclusion ids as strings" do
      expect(described_class.valid_values).to match_array(priority_ordered_ids.map(&:to_s))
    end
  end

  describe ".find" do
    it "returns the config entry for a given id" do
      entry = described_class.find(:is_veteran_with_disability)
      expect(entry[:id]).to eq(:is_veteran_with_disability)
      expect(entry[:priority]).to eq(30)
    end

    it "returns nil for an unknown id" do
      expect(described_class.find(:not_a_real_exclusion)).to be_nil
    end

    it "resolves a rules fact directly, since ruled ids match their fact names" do
      entry = described_class.find(:is_pregnant)
      expect(entry).to include(id: :is_pregnant, priority: 80)
    end
  end
end
