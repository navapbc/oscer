# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewExemptionClaimTask, type: :model do
  describe "inheritance" do
    it "inherits from Strata::Task" do
      expect(described_class < Strata::Task).to be true
    end
  end

  describe "create" do
    let(:certification_case) { create(:certification_case) }
    let!(:exemption_application_form) { create(:exemption_application_form, certification_case_id: certification_case.id) }

    it "binds to application form" do
      task = described_class.create!(case: certification_case)
      expect(task.application_form_id).to eq(exemption_application_form.id)
    end
  end
end
