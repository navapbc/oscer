# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/review_activity_report_tasks", type: :request do
  include Warden::Test::Helpers

  let(:user) { User.create!(email: "test@example.com", uid: SecureRandom.uuid, provider: "login.gov") }
  let(:kase) { create(:certification_case, business_process_current_step: "review_activity_report") }
  let(:task) { create(:review_activity_report_task, case: kase) }

  before do
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "PATCH /update" do
    context "with approve action" do
      before { patch review_activity_report_task_url(task), params: { review_activity_report_task: { activity_report_decision: "yes" } } }

      it "marks task as completed" do
        task.reload

        expect(task).to be_completed
      end

      it "marks case as approved" do
        kase.reload

        expect(kase.activity_report_approval_status).to eq("approved")
        expect(kase.business_process_instance.current_step).to eq("end")
        expect(kase).to be_closed
      end

      it "redirects back to the task" do
        expect(response).to redirect_to(task_path(task))
      end
    end

    context "with not acceptable action" do
      before { patch review_activity_report_task_url(task), params: { review_activity_report_task: { activity_report_decision: "no-not-acceptable" } } }

      it "marks task as completed" do
        task.reload

        expect(task).to be_completed
      end

      it "marks case as denied" do
        kase.reload

        expect(kase.activity_report_approval_status).to eq("denied")
        expect(kase.business_process_instance.current_step).to eq("end")
        expect(kase).to be_closed
      end

      it "redirects back to the task" do
        expect(response).to redirect_to(task_path(task))
      end
    end

    context "with needs more info action" do
      before { patch review_activity_report_task_url(task), params: { review_activity_report_task: { activity_report_decision: "no-additional-info" } } }

      it "marks task as pending" do
        task.reload

        expect(task).to be_pending
      end

      it "does not update the activity report approval status" do
        kase.reload

        expect(kase.activity_report_approval_status).to be_nil
        expect(kase.business_process_instance.current_step).to eq("review_activity_report")
        expect(kase).to be_open
      end

      it "redirects to the task" do
        expect(response).to redirect_to(request_information_review_activity_report_task_path(task))
      end
    end
  end

  describe "GET /request_information" do
    before { create(:activity_report_application_form, certification_case_id: kase.id) }

    it "renders a successful response" do
      get request_information_review_activity_report_task_path(task)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /create_information_request" do
    let(:activity_report_application_form) do
      build(:activity_report_application_form, certification_case_id: kase.id)
    end

    before { activity_report_application_form.save! }

    it "creates a new information request and marks the task as on hold" do
      form_params  =  { activity_report_information_request: { staff_comment: "Need more Info!" } }
      expect {
        post create_information_request_review_activity_report_task_path(task), params: form_params
      }.to change(ActivityReportInformationRequest, :count).from(0).to(1)

      expect(response).to redirect_to(certification_case_path(kase))

      task.reload
      expect(task).to be_on_hold
    end

    it "renders :unprocessable_entity when staff_comment is blank" do
      form_params  =  { activity_report_information_request: { staff_comment: "" } }
      expect {
        post create_information_request_review_activity_report_task_path(task), params: form_params
      }.not_to change(ActivityReportInformationRequest, :count)

      expect(response).to have_http_status(:unprocessable_entity)

      task.reload
      expect(task).to be_pending
    end
  end
end
