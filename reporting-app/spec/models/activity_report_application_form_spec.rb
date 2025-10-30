# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityReportApplicationForm, type: :model do
  describe "validations" do
    describe "certification_case_id uniqueness" do
      let(:certification) { create(:certification) }
      let(:certification_case) { create(:certification_case, certification: certification) }
      let(:user) { create(:user) }

      it "requires unique certification_case_id" do
        create(:activity_report_application_form, certification_case_id: certification_case.id)
        second_form = build(:activity_report_application_form, certification_case_id: certification_case.id)

        expect(second_form.save).to be(false)
        expect(second_form.errors[:certification_case_id]).to include("has already been taken")
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
