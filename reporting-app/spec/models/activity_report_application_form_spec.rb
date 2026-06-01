# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityReportApplicationForm, type: :model do
  describe "validations" do
    describe "certification_case_id" do
      let(:certification) { create(:certification) }
      let(:certification_case) { create(:certification_case, certification: certification) }

      before { allow(Strata::EventManager).to receive(:publish) }

      it "requires a certification_case_id" do
        form = build(:activity_report_application_form, certification_case_id: nil)

        expect(form.save).to be(false)
        expect(form.errors[:certification_case_id]).to include("can't be blank")
      end

      it "allows only one in-progress form per case" do
        create(:activity_report_application_form, certification_case_id: certification_case.id)
        second_form = build(:activity_report_application_form, certification_case_id: certification_case.id)

        expect(second_form.save).to be(false)
        expect(second_form.errors[:certification_case_id]).to include("has already been taken")
      end

      it "allows a new in-progress form once the prior form is submitted" do
        create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        second_form = build(:activity_report_application_form, certification_case_id: certification_case.id)

        expect(second_form.save).to be(true)
      end

      it "allows multiple submitted forms for the same case" do
        create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        second_form = create(:activity_report_application_form, certification_case_id: certification_case.id)

        expect(second_form.submit_application).to be(true)
      end

      it "allows different certification_case_ids" do
        certification_case_2 = create(:certification_case)
        create(:activity_report_application_form, certification_case_id: certification_case.id)
        second_form = build(:activity_report_application_form, certification_case_id: certification_case_2.id)

        expect(second_form.save).to be(true)
      end
    end
  end
end
