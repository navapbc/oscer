# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExemptionApplicationForm, type: :model do
  describe "attributes" do
    let(:exemption_form) { build(:exemption_application_form) }

    describe "#exemption_type" do
      it "can be set to valid types" do
        described_class.exemption_types.each do |k, v|
          exemption_form.exemption_type = v
          expect(exemption_form.exemption_type).to eq(v)
        end
      end

      it "cannot be set to an invalid type" do
        exemption_form.exemption_type = "invalid_type"
        expect(exemption_form.save).to be(false)
      end
    end
  end

  describe "validations" do
    describe "certification_case_id uniqueness" do
      let(:certification) { create(:certification) }
      let(:certification_case) { create(:certification_case, certification: certification) }

      it "requires unique certification_case_id" do
        create(:exemption_application_form, certification_case_id: certification_case.id)
        second_form = build(:exemption_application_form, certification_case_id: certification_case.id)

        expect(second_form.save).to be(false)
        expect(second_form.errors[:certification_case_id]).to include("has already been taken")
      end

      it "allows different certification_case_ids" do
        certification_case_2 = create(:certification_case)
        create(:exemption_application_form, certification_case_id: certification_case.id)
        second_form = build(:exemption_application_form, certification_case_id: certification_case_2.id)

        expect(second_form.save).to be(true)
      end
    end
  end
end
