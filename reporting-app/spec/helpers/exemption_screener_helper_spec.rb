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

    it "returns exemption title for exemption type steps" do
      exemption_type = Exemption.enabled.first[:id]
      expected = Exemption.title_for(exemption_type)
      expect(helper.exemption_screener_step_label(exemption_type)).to eq(expected)
    end

    it "returns correct labels for all enabled exemption types" do
      Exemption.enabled.each do |exemption|
        id = exemption[:id]
        expected_title = Exemption.title_for(id)
        expect(helper.exemption_screener_step_label(id)).to eq(expected_title)
      end
    end
  end
end
