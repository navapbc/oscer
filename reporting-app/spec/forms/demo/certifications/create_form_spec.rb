# frozen_string_literal: true

require "rails_helper"

RSpec.describe Demo::Certifications::CreateForm do
  describe "#to_certification external exception mapping" do
    subject(:member_data) { form.to_certification.member_data }

    let(:form) { described_class.new(certification_date: Date.current, external_exception: selected) }

    context "when inpatient medical care is selected" do
      let(:selected) { "inpatient_medical_care" }

      it "sets the matching member-data signal so the exception can be triggered" do
        expect(member_data.receiving_inpatient_medical_care).to be true
      end
    end

    context "when declared-emergency county is selected" do
      let(:selected) { "declared_emergency_county" }

      it "sets the matching member-data signal" do
        expect(member_data.resides_in_declared_emergency_county).to be true
      end
    end

    context "when high-unemployment county is selected" do
      let(:selected) { "high_unemployment_county" }

      it "sets the matching member-data signal" do
        expect(member_data.resides_in_high_unemployment_county).to be true
      end
    end

    context "when medical travel is selected" do
      let(:selected) { "medical_travel" }

      it "sets the matching member-data signal" do
        expect(member_data.traveling_for_medical_care).to be true
      end
    end

    context "when no external exception is selected" do
      let(:selected) { nil }

      it "leaves the exception signals at their defaults" do
        expect(member_data.receiving_inpatient_medical_care).to be false
        expect(member_data.resides_in_declared_emergency_county).to be false
        expect(member_data.resides_in_high_unemployment_county).to be false
        expect(member_data.traveling_for_medical_care).to be false
      end
    end
  end
end
