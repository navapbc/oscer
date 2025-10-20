# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/review_exemption_claim_tasks", type: :request do
  include Warden::Test::Helpers

  let(:user) { User.create!(email: "test@example.com", uid: SecureRandom.uuid, provider: "login.gov") }
  let(:certification_case) { create(:certification_case, business_process_current_step: "review_exemption_claim") }
  let(:task) { create(:review_exemption_claim_task, case: certification_case) }

  before do
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "PATCH /update" do
    context "with approve action" do
      before { patch review_exemption_claim_task_url(task), params: { review_exemption_claim_task: { exemption_decision: "yes" } } }

      it "marks task as completed" do
        task.reload
        expect(task).to be_completed
      end

      it "marks case exemption status as approved" do
        certification_case.reload
        expect(certification_case.exemption_request_approval_status).to eq("approved")
        expect(certification_case.business_process_instance.current_step).to eq("end")
        expect(certification_case).to be_closed
      end

      it "redirects back to the task" do
        expect(response).to redirect_to(task_path(task))
      end
    end

    context "with deny action" do
      before { patch review_exemption_claim_task_url(task), params: { review_exemption_claim_task: { exemption_decision: "no-not-acceptable" } } }

      it "marks task as completed" do
        task.reload
        expect(task).to be_completed
      end

      it "marks case exemption status as denied" do
        certification_case.reload
        expect(certification_case.exemption_request_approval_status).to eq("denied")
      end

      it "sets case step to report activities" do
        certification_case.reload
        expect(certification_case.business_process_instance.current_step).to eq("report_activities")
      end

      it "redirects back to the task" do
        expect(response).to redirect_to(task_path(task))
      end
    end

    context "with request information action" do
      before { patch review_exemption_claim_task_url(task), params: { review_exemption_claim_task: { exemption_decision: "no-additional-info" } } }

      it "redirects to the new information request form" do
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(request_information_review_exemption_claim_task_path(task))
        # Verify that the task is still pending
        expect(task.reload).to be_pending
      end
    end
  end

  describe "GET /request_information" do
    before { create(:exemption_application_form, certification_case_id: certification_case.id) }

    it "renders a successful response" do
      get request_information_review_exemption_claim_task_path(task)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /create_information_request" do
    let(:exemption_application_form) do
      build(:exemption_application_form, certification_case_id: certification_case.id)
    end

    before { exemption_application_form.save! }

    it "creates a new information request and marks the task as on hold" do
      form_params  =  { exemption_information_request: { staff_comment: "Need more Info!" } }
      expect {
        post create_information_request_review_exemption_claim_task_path(task), params: form_params
      }.to change(ExemptionInformationRequest, :count).from(0).to(1)

      expect(response).to redirect_to(certification_case_path(certification_case))

      task.reload
      expect(task).to be_on_hold
    end

    it "renders :unprocessable_entity when staff_comment is blank" do
      form_params  =  { exemption_information_request: { staff_comment: "" } }
      expect {
        post create_information_request_review_exemption_claim_task_path(task), params: form_params
      }.not_to change(ExemptionInformationRequest, :count)

      expect(response).to have_http_status(:unprocessable_entity)

      task.reload
      expect(task).to be_pending
    end
  end
end
