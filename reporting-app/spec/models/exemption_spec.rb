# frozen_string_literal: true

require "rails_helper"

RSpec.describe Exemption, type: :model do
  describe ".all" do
    it "returns all 6 exemption types" do
      expect(described_class.all.size).to eq(7)
    end

    it "contains specific exemption type IDs" do
      expected_ids = %i[
        caregiver_child
        caregiver_disability
        medical_condition
        substance_treatment
        incarceration
        education_and_training
        received_medical_care
      ]
      expect(described_class.all.map { |t| t[:id] }).to match_array(expected_ids)
    end
  end

  describe ".types" do
    it "returns the list of valid exemption type strings" do
      expected_types = [
        "caregiver_child",
        "caregiver_disability",
        "medical_condition",
        "substance_treatment",
        "incarceration",
        "education_and_training",
        "received_medical_care"
      ]
      expect(described_class.types).to match_array(expected_types)
    end
  end

  describe "accessors" do
    let(:type) { :caregiver_child }
    let(:config) { described_class.find(type) }

    describe ".title_for" do
      it "returns the title from translations" do
        expect(described_class.title_for(type)).to eq(I18n.t("exemption_types.#{type}.title"))
      end
    end

    describe ".description_for" do
      it "returns the description from translations" do
        expect(described_class.description_for(type)).to eq(I18n.t("exemption_types.#{type}.description"))
      end
    end

    describe ".supporting_documents_for" do
      it "returns the supporting documents from translations" do
        expect(described_class.supporting_documents_for(type)).to eq(I18n.t("exemption_types.#{type}.supporting_documents"))
      end
    end

    describe ".question_for" do
      it "returns the question from translations" do
        expect(described_class.question_for(type)).to eq(I18n.t("exemption_types.#{type}.question"))
      end
    end

    describe ".explanation_for" do
      it "returns the explanation from translations" do
        expect(described_class.explanation_for(type)).to eq(I18n.t("exemption_types.#{type}.explanation"))
      end
    end

    describe ".yes_answer_for" do
      it "returns the yes_answer from translations" do
        expect(described_class.yes_answer_for(type)).to eq(I18n.t("exemption_types.#{type}.yes_answer"))
      end
    end
  end

  describe ".find" do
    it "returns the correct config for a given type" do
      expect(described_class.find(:caregiver_child)[:id]).to eq(:caregiver_child)
    end

    it "returns nil for an invalid type" do
      expect(described_class.find(:invalid)).to be_nil
    end
  end
end
