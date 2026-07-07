# frozen_string_literal: true

require "rails_helper"

RSpec.describe Exclusion, type: :model do
  # The spec's default priority order (high durability -> low).
  let(:priority_ordered_ids) do
    %i[
      american_indian_alaska_native
      former_foster_care
      veteran_disability
      medically_frail
      caretaker
      tanf_snap_work
      drug_treatment
      pregnant
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
            { id: :pregnant, priority: 8 },
            { id: :american_indian_alaska_native, priority: 1 },
            { id: :veteran_disability, priority: 3 }
          ]
        )
      end

      it "returns entries sorted ascending by :priority" do
        expect(described_class.all.map { |t| t[:id] }).to eq(
          %i[american_indian_alaska_native veteran_disability pregnant]
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
      entry = described_class.find(:veteran_disability)
      expect(entry[:id]).to eq(:veteran_disability)
      expect(entry[:priority]).to eq(3)
    end

    it "returns nil for an unknown id" do
      expect(described_class.find(:not_a_real_exclusion)).to be_nil
    end
  end
end
