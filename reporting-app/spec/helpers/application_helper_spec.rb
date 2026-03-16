# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#exemption_type_title" do
    let(:exemption_application_form) { build(:exemption_application_form, exemption_type: exemption_type) }

    context "when exemption type exists in Exemption config" do
      let(:enabled_types) { Exemption.enabled.map { |t| t[:id] } }
      let(:exemption_type) { enabled_types.first.to_s }

      it "returns the title from Exemption config" do
        expected_title = Exemption.title_for(exemption_type)
        expect(helper.exemption_type_title(exemption_application_form)).to eq(expected_title)
      end
    end

    context "when exemption type is legacy and not in Exemption config" do
      let(:exemption_type) { "short_term_hardship" }

      it "falls back to humanize" do
        expect(helper.exemption_type_title(exemption_application_form)).to eq("Short term hardship")
      end
    end

    context "when exemption type is nil" do
      let(:exemption_type) { nil }

      it "returns nil" do
        expect(helper.exemption_type_title(exemption_application_form)).to be_nil
      end
    end
  end

  describe "#uswds_icon" do
    it "renders a decorative icon when no label is provided" do
      result = helper.uswds_icon("warning")
      expect(result).to include('aria-hidden="true"')
      expect(result).to include("#warning")
      expect(result).not_to include("<title>")
    end

    it "renders an accessible icon when label is provided" do
      result = helper.uswds_icon("warning", label: "Low confidence")
      expect(result).to include('aria-label="Low confidence"')
      expect(result).to include("<title>Low confidence</title>")
      expect(result).not_to include("aria-hidden")
    end

    it "applies the default size class" do
      result = helper.uswds_icon("check_circle")
      expect(result).to include("usa-icon--size-3")
    end

    it "applies a custom size class" do
      result = helper.uswds_icon("check_circle", size: 4)
      expect(result).to include("usa-icon--size-4")
    end

    it "omits size class when size is nil" do
      result = helper.uswds_icon("check_circle", size: nil)
      expect(result).to include("usa-icon")
      expect(result).not_to include("usa-icon--size-")
    end

    it "applies additional css_class" do
      result = helper.uswds_icon("warning", css_class: "text-error margin-right-1")
      expect(result).to include("usa-icon")
      expect(result).to include("text-error margin-right-1")
    end

    it "applies inline style when provided" do
      result = helper.uswds_icon("warning", style: "vertical-align: middle")
      expect(result).to include('style="vertical-align: middle"')
    end

    it "includes the sprite sheet href" do
      result = helper.uswds_icon("person")
      expect(result).to match(/sprite.*\.svg#person/)
    end
  end
end
