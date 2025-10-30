# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewActivityReportTask, type: :model do
  describe "inheritance" do
    it "inherits from Strata::Task" do
      expect(described_class.superclass).to eq(Strata::Task)
    end

    it "has a case_type of CertificationCase" do
      task = create(:review_activity_report_task, case: create(:certification_case))
      expect(task.case_type).to eq("CertificationCase")
    end
  end
end
