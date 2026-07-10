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
            { id: :pregnant, priority: 80 },
            { id: :american_indian_alaska_native, priority: 10 },
            { id: :veteran_disability, priority: 30 }
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
      expect(entry[:priority]).to eq(30)
    end

    it "returns nil for an unknown id" do
      expect(described_class.find(:not_a_real_exclusion)).to be_nil
    end
  end

  describe ".find_by_fact" do
    it "returns the config entry for a ruled fact" do
      entry = described_class.find_by_fact(:is_veteran_with_disability)
      expect(entry[:id]).to eq(:veteran_disability)
    end

    it "returns nil for a fact with no configured exclusion" do
      expect(described_class.find_by_fact(:not_a_real_fact)).to be_nil
    end
  end

  # Guards the fact/config/reason-code seam at test time so drift is caught here
  # rather than as a fail-loud KeyError in the determination flow. Only ruled
  # exclusions (those with a :fact) participate; declarative entries are exempt.
  describe "fact bridging (drift guard)" do
    let(:ruled_facts) { described_class.all.filter_map { |t| t[:fact] } }

    it "resolves every ruled fact through find_by_fact to a priority-carrying entry" do
      ruled_facts.each do |fact|
        expect(described_class.find_by_fact(fact)).to include(:priority)
      end
    end

    it "bridges only facts that map to a determination reason code" do
      ruled_facts.each do |fact|
        expect(Determination::REASON_CODE_MAPPING).to include(fact.to_sym)
      end
    end
  end
end
