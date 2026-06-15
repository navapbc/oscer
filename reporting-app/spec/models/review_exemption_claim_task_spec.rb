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

  describe "#approval_status" do
    let(:certification_case) { create(:certification_case) }

    it "is nil (undecided) by default, distinguishable from approved/denied" do
      task = create(:review_exemption_claim_task_with_form, case: certification_case)

      expect(task.approval_status).to be_nil
      expect(task).not_to be_approved
      expect(task).not_to be_denied
    end

    it "records an approved decision" do
      task = create(:review_exemption_claim_task_with_form, case: certification_case, approval_status: :approved)

      expect(task.approval_status).to eq("approved")
      expect(task).to be_approved
    end

    it "records a denied decision" do
      task = create(:review_exemption_claim_task_with_form, case: certification_case, approval_status: :denied)

      expect(task.approval_status).to eq("denied")
      expect(task).to be_denied
    end
  end
end
