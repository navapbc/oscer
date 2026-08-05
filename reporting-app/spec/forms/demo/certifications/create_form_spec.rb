# frozen_string_literal: true

require "rails_helper"

RSpec.describe Demo::Certifications::CreateForm do
  describe "#to_certification external exception mapping" do
    subject(:member_data) { certification.member_data }

    let(:form) { described_class.new(certification_date: Date.current, external_exception: selected) }
    let(:certification) { form.to_certification }
    let(:months) { certification.certification_requirements.months_that_can_be_certified }

    # The added exemption spans the certifiable months, so ExceptionDeterminationService finds it
    # covering one of them.
    shared_examples "an external exception exemption" do |exemption_type|
      it "adds a verified #{exemption_type} exemption spanning the certifiable months" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq exemption_type
        expect(exemption.value).to be true
        expect(exemption.verification_status).to eq "verified"
        expect(exemption.periods.first.period_start).to eq months.min
        expect(exemption.periods.first.period_end).to eq months.max.end_of_month
      end
    end

    context "when inpatient medical care is selected" do
      let(:selected) { "inpatient_medical_care" }

      it_behaves_like "an external exception exemption", "inpatient_medical_care"
    end

    context "when declared-emergency county is selected" do
      let(:selected) { "declared_emergency_county" }

      it_behaves_like "an external exception exemption", "declared_emergency_county"
    end

    context "when high-unemployment county is selected" do
      let(:selected) { "high_unemployment_county" }

      it_behaves_like "an external exception exemption", "high_unemployment_county"
    end

    context "when medical travel is selected" do
      let(:selected) { "medical_travel" }

      it_behaves_like "an external exception exemption", "travel_for_medical"
    end

    context "when other program is selected" do
      let(:selected) { "other_program" }

      it_behaves_like "an external exception exemption", "other_program"
    end

    context "when no external exception is selected" do
      let(:selected) { nil }

      it "does not add exemptions" do
        expect(member_data.exemptions.length).to be_zero
      end
    end

    context "when pregnancy is selected" do
      let(:form) { described_class.new(certification_date: Date.current, pregnancy_status: true) }

      it "Adds exemption to member data" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq 'pregnancy'
        expect(exemption.periods.first.period_end).to eq form.certification_date
      end
    end

    context "when was_in_foster_care is selected" do
      let(:form) { described_class.new(certification_date: Date.current, was_in_foster_care: true) }

      it "Adds exemption to member data" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq 'former_foster_care'
        expect(exemption.periods.first.period_end).to eq form.certification_date
      end
    end

    context "when currently_medically_frail is selected" do
      let(:form) { described_class.new(certification_date: Date.current, currently_medically_frail: true) }

      it "Adds exemption to member data" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq 'medical_condition'
        expect(exemption.periods.first.period_end).to eq form.certification_date
      end
    end

    context "when veteran_with_disability is selected" do
      let(:form) { described_class.new(certification_date: Date.current, veteran_with_disability: true) }

      it "Adds exemption to member data" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq 'veteran_disability'
        expect(exemption.periods.first.period_end).to eq form.certification_date
      end
    end

    context "when caretaker is selected" do
      let(:form) { described_class.new(certification_date: Date.current, caretaker: true) }

      it "Adds exemption to member data" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq 'caregiver_disability'
        expect(exemption.periods.first.period_end).to eq form.certification_date
      end
    end

    context "when tanf_snap_work is selected" do
      let(:form) { described_class.new(certification_date: Date.current, tanf_snap_work: true) }

      it "Adds exemption to member data" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq 'meeting_tanf_or_snap_work'
        expect(exemption.periods.first.period_end).to eq form.certification_date
      end
    end

    context "when drug_treatment is selected" do
      let(:form) { described_class.new(certification_date: Date.current, drug_treatment: true) }

      it "Adds exemption to member data" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq 'substance_treatment'
        expect(exemption.periods.first.period_end).to eq form.certification_date
      end
    end

    context "when inmate is selected" do
      let(:form) { described_class.new(certification_date: Date.current, inmate: true) }

      it "Adds exemption to member data" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq 'incarceration'
        expect(exemption.periods.first.period_end).to eq form.certification_date
      end
    end

    context "when race_ethnicity is american_indian_or_alaska_native" do
      let(:form) { described_class.new(certification_date: Date.current, race_ethnicity: 'american_indian_or_alaska_native') }

      it "Adds exemption to member data" do
        expect(member_data.exemptions.length).to eq 1
        exemption = member_data.exemptions.first
        expect(exemption.type).to eq 'american_indian_or_alaska_native'
        expect(exemption.periods.first.period_end).to eq form.certification_date
      end
    end
  end
end
