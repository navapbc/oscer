# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExemptionScreenerNavigator do
  let(:config) { ExemptionScreenerConfig.new }
  let(:first_exemption_type) { config.exemption_types.first }
  let(:second_exemption_type) { config.exemption_types.second }
  let(:last_exemption_type) { config.exemption_types.last }

  describe "#current_question" do
    context "with valid exemption type and question index" do
      it "returns the question hash" do
        navigator = described_class.new(config, first_exemption_type, 0)

        question = navigator.current_question

        expect(question).to be_a(Hash)
        expect(question).to have_key("question")
        expect(question).to have_key("description")
        expect(question).to have_key("yes_answer")
      end
    end

    context "with invalid exemption type" do
      it "returns nil" do
        navigator = described_class.new(config, "invalid_type", 0)

        expect(navigator.current_question).to be_nil
      end
    end

    context "with invalid question index" do
      it "returns nil" do
        navigator = described_class.new(config, first_exemption_type, 999)

        expect(navigator.current_question).to be_nil
      end
    end
  end

  describe "#next_location" do
    context "when answer is yes" do
      it "returns may_qualify action with exemption type" do
        navigator = described_class.new(config, first_exemption_type, 0)

        action, exemption_type = navigator.next_location(answer: "yes")

        expect(action).to eq(:may_qualify)
        expect(exemption_type).to eq(first_exemption_type)
      end
    end

    context "when answer is no and there are more questions in current exemption type" do
      it "returns question action with next question index" do
        # Assuming first_exemption_type has at least 2 questions
        navigator = described_class.new(config, first_exemption_type, 0)

        action, exemption_type, question_index = navigator.next_location(answer: "no")

        expect(action).to eq(:question)
        expect(exemption_type).to eq(first_exemption_type)
        expect(question_index).to eq(1)
      end
    end

    context "when answer is no and at end of current exemption type" do
      it "returns question action with first question of next exemption type" do
        # Get last question index of first exemption type
        last_question_index = config.questions_for(first_exemption_type).count - 1
        navigator = described_class.new(config, first_exemption_type, last_question_index)

        action, exemption_type, question_index = navigator.next_location(answer: "no")

        expect(action).to eq(:question)
        expect(exemption_type).to eq(second_exemption_type)
        expect(question_index).to eq(0)
      end
    end

    context "when answer is no and at end of all questions" do
      it "returns complete action" do
        # Get last question index of last exemption type
        last_question_index = config.questions_for(last_exemption_type).count - 1
        navigator = described_class.new(config, last_exemption_type, last_question_index)

        action = navigator.next_location(answer: "no")

        expect(action).to eq([ :complete ])
      end
    end
  end

  describe "#previous_location" do
    context "when at first question of first exemption type" do
      it "returns nil" do
        navigator = described_class.new(config, first_exemption_type, 0)

        expect(navigator.previous_location).to be_nil
      end
    end

    context "when at second question of first exemption type" do
      it "returns first question of same exemption type" do
        navigator = described_class.new(config, first_exemption_type, 1)

        exemption_type, question_index = navigator.previous_location

        expect(exemption_type).to eq(first_exemption_type)
        expect(question_index).to eq(0)
      end
    end

    context "when at first question of second exemption type" do
      it "returns last question of first exemption type" do
        navigator = described_class.new(config, second_exemption_type, 0)

        exemption_type, question_index = navigator.previous_location

        expect(exemption_type).to eq(first_exemption_type)
        expect(question_index).to eq(config.questions_for(first_exemption_type).count - 1)
      end
    end
  end

  describe "#valid?" do
    context "with valid exemption type and question index" do
      it "returns true" do
        navigator = described_class.new(config, first_exemption_type, 0)

        expect(navigator).to be_valid
      end
    end

    context "with invalid exemption type" do
      it "returns false" do
        navigator = described_class.new(config, "invalid_type", 0)

        expect(navigator).not_to be_valid
      end
    end

    context "with out of range question index" do
      it "returns false" do
        navigator = described_class.new(config, first_exemption_type, 999)

        expect(navigator).not_to be_valid
      end
    end

    context "with negative question index" do
      it "returns false" do
        navigator = described_class.new(config, first_exemption_type, -1)

        expect(navigator).not_to be_valid
      end
    end
  end
end
