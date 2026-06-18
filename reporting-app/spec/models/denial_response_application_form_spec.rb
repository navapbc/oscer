# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DenialResponseApplicationForm, type: :model do
  describe "attributes" do
    it "stores the member comment" do
      form = build(:denial_response_application_form, comment: "I have a good reason.")
      expect(form.comment).to eq("I have a good reason.")
    end

    it "accepts optional supporting documents" do
      form = create(:denial_response_application_form)
      form.supporting_documents.attach(
        io: StringIO.new("doc"), filename: "evidence.pdf", content_type: "application/pdf"
      )

      expect(form.supporting_documents).to be_attached
    end
  end

  describe "validations" do
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    it "requires a certification case" do
      form = build(:denial_response_application_form, certification_case_id: nil)
      expect(form.save).to be(false)
      expect(form.errors[:certification_case_id]).to include("can't be blank")
    end

    it "allows only one in-progress form per case" do
      create(:denial_response_application_form, certification_case_id: certification_case.id)
      second_form = build(:denial_response_application_form, certification_case_id: certification_case.id)

      expect(second_form.save).to be(false)
      expect(second_form.errors[:certification_case_id]).to include("has already been taken")
    end

    it "allows different certification_case_ids" do
      certification_case_2 = create(:certification_case)
      create(:denial_response_application_form, certification_case_id: certification_case.id)
      second_form = build(:denial_response_application_form, certification_case_id: certification_case_2.id)

      expect(second_form.save).to be(true)
    end

    # Submitting moves the case to review and the business process creates the review task, so the
    # prior form here is submitted (not in progress) — isolating the review-task branch of
    # has_pending_form.
    context "with a prior submitted form whose review task is still open" do
      let!(:first_form) { create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id) }
      let(:review_task) { ReviewDenialResponseTask.find_by(application_form: first_form) }

      it "does not allow a new form while the review task is pending" do
        second_form = build(:denial_response_application_form, certification_case_id: certification_case.id)

        expect(second_form.save).to be(false)
        expect(second_form.errors[:certification_case_id]).to include("has already been taken")
      end

      it "does not allow a new form while the review task is on hold" do
        review_task.on_hold!
        second_form = build(:denial_response_application_form, certification_case_id: certification_case.id)

        expect(second_form.save).to be(false)
      end

      it "allows a new form once the review task is completed" do
        review_task.completed!
        second_form = build(:denial_response_application_form, certification_case_id: certification_case.id)

        expect(second_form.save).to be(true)
      end
    end

    context "when case is closed" do
      before { certification_case.close! }

      it "does not allow creation" do
        form = build(:denial_response_application_form, certification_case_id: certification_case.id)
        expect(form.save).to be(false)
        expect(form.errors[:certification_case_id]).to include("has closed")
      end
    end

    context "when verification window has ended" do
      before { certification_case.update_attribute(:verification_window_end_date, 1.day.ago) }

      it "does not allow creation" do
        form = build(:denial_response_application_form, certification_case_id: certification_case.id)
        expect(form.save).to be(false)
        expect(form.errors[:certification_case_id]).to include("verification window has ended")
      end
    end

    context "when verification window is open" do
      before { certification_case.update_attribute(:verification_window_end_date, 1.day.from_now) }

      it "allows creation" do
        form = build(:denial_response_application_form, certification_case_id: certification_case.id)
        expect(form.save).to be(true)
      end
    end
  end

  describe "#approval_status" do
    it "has no outcome when there is no review task, distinguishable from approved/denied" do
      form = create(:denial_response_application_form)

      expect(form.approval_status).to be_nil
      expect(form).not_to be_approved
      expect(form).not_to be_denied
    end

    it "reports its review task's approved outcome" do
      task = create(:review_denial_response_task_with_form, case: create(:certification_case))
      task.update!(approval_status: :approved)

      form = described_class.find(task.application_form_id)
      expect(form.approval_status).to eq("approved")
      expect(form).to be_approved
    end

    it "reports its review task's denied outcome" do
      task = create(:review_denial_response_task_with_form, case: create(:certification_case))
      task.update!(approval_status: :denied)

      form = described_class.find(task.application_form_id)
      expect(form.approval_status).to eq("denied")
      expect(form).to be_denied
    end
  end

  describe "#flow_status" do
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    # Publishing is stubbed so the business process does not create a competing review task; each
    # test creates exactly the review task it needs.
    before { allow(Strata::EventManager).to receive(:publish) }

    context "without previous denial response" do
      it "returns 'in_progress' when not submitted" do
        form = create(:denial_response_application_form, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "in_progress"
      end

      it "returns 'submitted' when submitted with no review task" do
        form = create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'submitted' while the review task is pending" do
        form = create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        create(:review_denial_response_task, application_form: form, case: certification_case)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'approved' once the review task is completed and the case is approved" do
        form = create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_denial_response_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.accept_denial_response(nil, form)

        expect(form.flow_status).to eq "approved"
      end

      it "returns 'denied' once the review task is completed and the case is denied" do
        form = create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_denial_response_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.deny_denial_response(nil, form)

        expect(form.flow_status).to eq "denied"
      end
    end

    context "with previous activity report" do
      before do
        previous_form = create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        certification_case.deny_denial_response(nil, previous_form)
      end

      it "returns 'in_progress' when not submitted" do
        form = create(:denial_response_application_form, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "in_progress"
      end

      it "returns 'submitted' when submitted with no review task" do
        form = create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'submitted' while the review task is pending" do
        form = create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        create(:review_denial_response_task, application_form: form, case: certification_case)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'approved' once the review task is completed and the case is approved" do
        form = create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_denial_response_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.accept_denial_response(nil, form)

        expect(form.flow_status).to eq "approved"
      end

      it "returns 'denied' once the review task is completed and the case is denied" do
        form = create(:denial_response_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_denial_response_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.deny_denial_response(nil, form)

        expect(form.flow_status).to eq "denied"
      end
    end
  end
end
