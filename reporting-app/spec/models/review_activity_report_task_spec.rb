# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewActivityReportTask, type: :model do
  describe "inheritance" do
    it "inherits from Strata::Task" do
      expect(described_class < Strata::Task).to be true
    end

    it "has a case_type of CertificationCase" do
      task = create(:review_activity_report_task_with_form, case: create(:certification_case))
      expect(task.case_type).to eq("CertificationCase")
    end
  end

  describe "create" do
    let(:certification_case) { create(:certification_case) }
    let!(:activity_report_application_form) { create(:activity_report_application_form, certification_case_id: certification_case.id) }

    it "binds to application form" do
      task = described_class.create!(case: certification_case)
      expect(task.application_form_id).to eq(activity_report_application_form.id)
    end
  end
end
