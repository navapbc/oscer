# frozen_string_literal: true

require "rails_helper"

describe ExemptionTypeConfig, type: :model do
  describe ".all" do
    it "returns all 6 exemption types" do
      expect(described_class.all.size).to eq(6)
    end

    it "contains specific exemption type IDs" do
      expected_ids = %i[
        care_giver_child
        medical_condition
        substance_treatment
        incarceration
        education_and_training
        received_medical_care
      ]
      expect(described_class.all.map { |t| t[:id] }).to match_array(expected_ids)
    end
  end

  describe "accessors" do
    let(:type) { :care_giver_child }
    let(:config) { described_class.find(type) }

    describe ".title_for" do
      it "returns the title" do
        expect(described_class.title_for(type)).to eq(config[:title])
      end
    end

    describe ".description_for" do
      it "returns the description" do
        expect(described_class.description_for(type)).to eq(config[:description])
      end
    end

    describe ".supporting_documents_for" do
      it "returns the supporting documents" do
        expect(described_class.supporting_documents_for(type)).to eq(config[:supporting_documents])
      end
    end

    describe ".question_for" do
      it "returns the question" do
        expect(described_class.question_for(type)).to eq(config[:question])
      end
    end

    describe ".explanation_for" do
      it "returns the explanation" do
        expect(described_class.explanation_for(type)).to eq(config[:explanation])
      end
    end

    describe ".yes_answer_for" do
      it "returns the yes_answer" do
        expect(described_class.yes_answer_for(type)).to eq(config[:yes_answer])
      end
    end
  end

  describe ".find" do
    it "returns the correct config for a given type" do
      expect(described_class.find(:care_giver_child)[:title]).to eq("Parent or Caregiver of Dependent Age 13 or Younger")
    end

    it "returns nil for an invalid type" do
      expect(described_class.find(:invalid)).to be_nil
    end
  end
end
