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
end
