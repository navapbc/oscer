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
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    it "allows only one in-progress form per case" do
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

    context "with existing submitted form" do
      let!(:first_form) { create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

      it "does not allows a new form if task is still pending" do
        second_form = build(:exemption_application_form, certification_case_id: certification_case.id)

        expect(second_form.save).to be(false)
        expect(second_form.errors[:certification_case_id]).to include("has already been taken")
      end

      context "with task completed" do
        before { ReviewExemptionClaimTask.find_by(application_form: first_form).completed! }

        it "allows a new form" do
          second_form = build(:exemption_application_form, certification_case_id: certification_case.id)

          expect(second_form.save).to be(true)
        end

        it "allows multiple submitted forms for the same case" do
          second_form = create(:exemption_application_form, certification_case_id: certification_case.id)

          expect(second_form.submit_application).to be(true)
        end
      end
    end
  end

  describe "flow status" do
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    before { allow(Strata::EventManager).to receive(:publish) }

    context "without previous exemption request" do
      it "returns 'in progress' when not submitted" do
        form = create(:exemption_application_form, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "in_progress"
      end

      it "returns 'submitted' when no task" do
        form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'submitted' when task pending" do
        form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_exemption_claim_task, application_form: form, case: certification_case)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'approved' when approved" do
        form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_exemption_claim_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.accept_exemption_request(nil)
        expect(form.flow_status).to eq "approved"
      end

      it "returns 'denied' when denied" do
        form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_exemption_claim_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.deny_exemption_request(nil)
        expect(form.flow_status).to eq "denied"
      end
    end

    context "with previous exemption request" do
      before do
        create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        certification_case.deny_exemption_request(nil)
      end

      it "returns 'in progress' when not submitted" do
        form = create(:exemption_application_form, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "in_progress"
      end

      it "returns 'submitted' when no task" do
        form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'submitted' when task pending" do
        form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_exemption_claim_task, application_form: form, case: certification_case)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'approved' when approved" do
        form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_exemption_claim_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.accept_exemption_request(nil)
        expect(form.flow_status).to eq "approved"
      end

      it "returns 'denied' when denied" do
        form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_exemption_claim_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.deny_exemption_request(nil)
        expect(form.flow_status).to eq "denied"
      end
    end
  end
end
