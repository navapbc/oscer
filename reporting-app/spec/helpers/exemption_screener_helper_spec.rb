# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExemptionScreenerHelper, type: :helper do
  describe "#exemption_screener_steps" do
    it "returns array starting with :start" do
      expect(helper.exemption_screener_steps.first).to eq(:start)
    end

    it "ends with :result" do
      expect(helper.exemption_screener_steps.last).to eq(:result)
    end

    it "includes all enabled exemption type IDs" do
      enabled_ids = Exemption.enabled.map { |t| t[:id] }
      steps = helper.exemption_screener_steps
      enabled_ids.each do |id|
        expect(steps).to include(id)
      end
    end

    it "has length of enabled types + 2" do
      expected_length = Exemption.enabled.count + 2
      expect(helper.exemption_screener_steps.length).to eq(expected_length)
    end

    it "maintains order of enabled exemption types" do
      enabled_ids = Exemption.enabled.map { |t| t[:id] }
      steps = helper.exemption_screener_steps[1..-2] # exclude :start and :result
      expect(steps).to eq(enabled_ids)
    end

    it "memoizes the result" do
      first_call = helper.exemption_screener_steps
      second_call = helper.exemption_screener_steps
      expect(first_call.object_id).to eq(second_call.object_id)
    end
  end

  describe "#exemption_screener_step_label" do
    it "returns translation for :start" do
      expect(helper.exemption_screener_step_label(:start)).to eq(I18n.t("exemption_screener.steps.start"))
    end

    it "returns translation for :result" do
      expect(helper.exemption_screener_step_label(:result)).to eq(I18n.t("exemption_screener.steps.result"))
    end

    it "returns 'Exemption Questions' label for exemption type steps" do
      exemption_type = Exemption.enabled.first[:id]
      expected = I18n.t("exemption_screener.steps.questions")
      expect(helper.exemption_screener_step_label(exemption_type)).to eq(expected)
    end

    it "returns 'Exemption Questions' for all enabled exemption types" do
      Exemption.enabled.each do |exemption|
        id = exemption[:id]
        expected = I18n.t("exemption_screener.steps.questions")
        expect(helper.exemption_screener_step_label(id)).to eq(expected)
      end
    end
  end

  describe "#exemption_screener_step_status" do
    it "returns 'complete' when step_index is less than current_index" do
      expect(helper.exemption_screener_step_status(0, 2)).to eq("complete")
      expect(helper.exemption_screener_step_status(1, 3)).to eq("complete")
    end

    it "returns 'current' when step_index equals current_index" do
      expect(helper.exemption_screener_step_status(2, 2)).to eq("current")
      expect(helper.exemption_screener_step_status(0, 0)).to eq("current")
    end

    it "returns 'incomplete' when step_index is greater than current_index" do
      expect(helper.exemption_screener_step_status(3, 1)).to eq("incomplete")
      expect(helper.exemption_screener_step_status(5, 2)).to eq("incomplete")
    end
  end

  describe "#back_button_with_icon" do
    it "renders a link with icon and text" do
      result = helper.back_button_with_icon("Back", "/path", class: "usa-button")
      expect(result).to include('href="/path"')
      expect(result).to include('class="usa-button"')
      expect(result).to include('usa-icon')
      expect(result).to include('Back')
    end
  end

  describe "#exemption_screener_back_button" do
    let(:certification_case) { double(id: 123) }

    context "when previous_exemption_type is present" do
      it "returns link to previous question" do
        result = helper.exemption_screener_back_button("caregiver_child", certification_case)
        expect(result).to include('/exemption-screener/question/caregiver_child')
        expect(result).to include('certification_case_id')
        expect(result).to include(I18n.t("exemption_screener.show.buttons.back_to_previous"))
      end
    end

    context "when previous_exemption_type is nil" do
      it "returns link to screener index" do
        result = helper.exemption_screener_back_button(nil, certification_case)
        expect(result).to include('/exemption-screener')
        expect(result).to include('certification_case_id')
        expect(result).to include(I18n.t("exemption_screener.show.buttons.back"))
      end
    end
  end
end
