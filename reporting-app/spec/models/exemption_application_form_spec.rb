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

      context "with task on hold" do
        before { ReviewExemptionClaimTask.find_by(application_form: first_form).on_hold! }

        it "does not allow a new form" do
          second_form = build(:exemption_application_form, certification_case_id: certification_case.id)

          expect(second_form.save).to be(false)
        end
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

    context "when certification closed" do
      before { certification_case.close! }

      it "does not allow creation" do
        form = build(:exemption_application_form, certification_case_id: certification_case.id)
        expect(form.save).to be(false)
      end
    end

    context "when verification window closed" do
      before { certification_case.update_attribute(:verification_window_end_date, 1.day.ago) }

      it "does not allow creation" do
        form = build(:exemption_application_form, certification_case_id: certification_case.id)
        expect(form.save).to be(false)
      end
    end

    context "when verification window open" do
      before { certification_case.update_attribute(:verification_window_end_date, 1.day.from_now) }

      it "allows creation" do
        form = build(:exemption_application_form, certification_case_id: certification_case.id)
        expect(form.save).to be(true)
      end
    end
  end

  describe "#approval_status" do
    it "has no outcome when there is no review task, distinguishable from approved/denied" do
      form = create(:exemption_application_form)

      expect(form.approval_status).to be_nil
      expect(form).not_to be_approved
      expect(form).not_to be_denied
    end

    it "has no outcome while its review task is undecided" do
      task = create(:review_exemption_claim_task_with_form, case: create(:certification_case))

      expect(task.application_form.approval_status).to be_nil
    end

    it "reports its review task's approved outcome" do
      task = create(:review_exemption_claim_task_with_form, case: create(:certification_case))
      task.update!(approval_status: :approved)

      form = described_class.find(task.application_form_id)
      expect(form.approval_status).to eq("approved")
      expect(form).to be_approved
    end

    it "reports its review task's denied outcome" do
      task = create(:review_exemption_claim_task_with_form, case: create(:certification_case))
      task.update!(approval_status: :denied)

      form = described_class.find(task.application_form_id)
      expect(form.approval_status).to eq("denied")
      expect(form).to be_denied
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
        certification_case.accept_exemption_request(nil, form)
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
        certification_case.accept_exemption_request(nil, form)
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
