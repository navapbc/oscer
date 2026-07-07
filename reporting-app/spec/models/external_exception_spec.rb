# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalException, type: :model do
  describe ".all" do
    it "returns all 4 external exceptions" do
      expect(described_class.all.size).to eq(4)
    end

    it "contains the specific external-exception IDs" do
      expected_ids = %i[
        inpatient_medical_care
        declared_emergency_county
        high_unemployment_county
        medical_travel
      ]
      expect(described_class.all.map { |t| t[:id] }).to match_array(expected_ids)
    end
  end

  describe ".ids" do
    it "returns the list of external-exception ids as symbols" do
      expect(described_class.ids).to match_array(
        %i[inpatient_medical_care declared_emergency_county high_unemployment_county medical_travel]
      )
    end
  end

  describe ".find" do
    it "returns the config entry for a given id" do
      expect(described_class.find(:inpatient_medical_care)[:id]).to eq(:inpatient_medical_care)
    end

    it "accepts a string id" do
      expect(described_class.find("medical_travel")[:id]).to eq(:medical_travel)
    end

    it "returns nil for an unknown id" do
      expect(described_class.find(:not_a_real_exception)).to be_nil
    end
  end

  describe ".valid_type?" do
    it "is true for a known id (regardless of enabled state)" do
      expect(described_class.valid_type?(:medical_travel)).to be true
    end

    it "is false for an unknown id" do
      expect(described_class.valid_type?(:not_a_real_exception)).to be false
    end
  end

  describe ".enabled and .enabled?" do
    context "when all defaults are enabled" do
      it ".enabled returns all four" do
        expect(described_class.enabled.map { |t| t[:id] }).to match_array(
          %i[inpatient_medical_care declared_emergency_county high_unemployment_county medical_travel]
        )
      end

      it ".enabled? is true for each id (string or symbol)" do
        expect(described_class.enabled?(:medical_travel)).to be true
        expect(described_class.enabled?("inpatient_medical_care")).to be true
      end

      it ".enabled? is false for an unknown id" do
        expect(described_class.enabled?(:not_a_real_exception)).to be false
      end
    end

    context "when a type is disabled via configuration" do
      before do
        allow(Rails.application.config).to receive(:external_exceptions).and_return(
          [
            { id: :inpatient_medical_care, enabled: true },
            { id: :declared_emergency_county, enabled: true },
            { id: :high_unemployment_county, enabled: false },
            { id: :medical_travel, enabled: true }
          ]
        )
      end

      it ".enabled excludes the disabled type" do
        expect(described_class.enabled.map { |t| t[:id] }).not_to include(:high_unemployment_county)
      end

      it ".enabled? is false for the disabled type" do
        expect(described_class.enabled?(:high_unemployment_county)).to be false
      end

      it ".enabled? remains true for the still-enabled types" do
        expect(described_class.enabled?(:inpatient_medical_care)).to be true
      end

      it ".valid_type? is still true for the disabled type (known but off)" do
        expect(described_class.valid_type?(:high_unemployment_county)).to be true
      end
    end
  end
end
