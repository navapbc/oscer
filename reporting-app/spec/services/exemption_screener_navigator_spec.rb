# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExemptionScreenerNavigator do
  let(:enabled_types) { Exemption.enabled.map { |t| t[:id] } }
  let(:first_exemption_type) { enabled_types.first }
  let(:second_exemption_type) { enabled_types.second }
  let(:last_exemption_type) { enabled_types.last }

  describe "#current_question" do
    context "with valid exemption type" do
      it "returns the question hash" do
        navigator = described_class.new(first_exemption_type)

        question = navigator.current_question

        expect(question).to be_a(Hash)
        expect(question).to have_key("question")
        expect(question).to have_key("explanation")
        expect(question).to have_key("yes_answer")
      end
    end

    context "with invalid exemption type" do
      it "returns nil" do
        navigator = described_class.new("invalid_type")

        expect(navigator.current_question).to be_nil
      end
    end
  end

  describe "#next_location" do
    context "when answer is yes" do
      it "returns ExemptionNavigation with may_qualify action and exemption type location" do
        navigator = described_class.new(first_exemption_type)

        navigation = navigator.next_location(answer: "yes")

        expect(navigation).to be_a(ExemptionScreenerNavigator::ExemptionNavigation)
        expect(navigation.action).to eq(:may_qualify)
        expect(navigation.location).to eq(first_exemption_type)
      end
    end

    context "when answer is no and there are more exemption types" do
      it "returns ExemptionNavigation with question action and next exemption type location" do
        navigator = described_class.new(first_exemption_type)

        navigation = navigator.next_location(answer: "no")

        expect(navigation).to be_a(ExemptionScreenerNavigator::ExemptionNavigation)
        expect(navigation.action).to eq(:question)
        expect(navigation.location).to eq(second_exemption_type)
      end
    end

    context "when answer is no and at last exemption type" do
      it "returns ExemptionNavigation with complete action and no location" do
        navigator = described_class.new(last_exemption_type)

        navigation = navigator.next_location(answer: "no")

        expect(navigation).to be_a(ExemptionScreenerNavigator::ExemptionNavigation)
        expect(navigation.action).to eq(:complete)
        expect(navigation.location).to be_nil
      end
    end
  end

  describe "#previous_location" do
    context "when at first exemption type" do
      it "returns nil" do
        navigator = described_class.new(first_exemption_type)

        expect(navigator.previous_location).to be_nil
      end
    end

    context "when at second exemption type" do
      it "returns first exemption type" do
        navigator = described_class.new(second_exemption_type)

        previous_type = navigator.previous_location

        expect(previous_type).to eq(first_exemption_type)
      end
    end
  end

  describe "#valid?" do
    context "with valid exemption type" do
      it "returns true" do
        navigator = described_class.new(first_exemption_type)

        expect(navigator).to be_valid
      end
    end

    context "with invalid exemption type" do
      it "returns false" do
        navigator = described_class.new("invalid_type")

        expect(navigator).not_to be_valid
      end
    end
  end
end
