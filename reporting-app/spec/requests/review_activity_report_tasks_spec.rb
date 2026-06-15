# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/review_activity_report_tasks", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user, :as_caseworker, region: "Southeast") }
  let(:certification) { create(:certification, certification_requirements: build(:certification_certification_requirements, region: "Southeast")) }
  let(:kase) { create(:certification_case, certification_id: certification.id, business_process_current_step: "review_activity_report") }
  let(:task) { create(:review_activity_report_task_with_form, case: kase) }

  before do
    login_as user
    allow(NotificationService).to receive(:send_email_notification)

    # Keep the bootstrap community-engagement check from closing the factory-created case
    # (the hours stub below would otherwise mark it compliant during certification setup).
    allow(CommunityEngagementCheckService).to receive(:determine) do |bootstrap_case|
      Strata::EventManager.publish("DeterminedCommunityEngagementActionRequired", {
        case_id: bootstrap_case.id,
        certification_id: bootstrap_case.certification_id
      })
    end
  end

  after do
    Warden.test_reset!
  end

  describe "PATCH /update" do
    context "with approve action" do
      let(:approve_params) { { review_activity_report_task: { activity_report_decision: :yes } } }

      before do
        # Stub aggregate_hours_for_certification for the model's accept method
        allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_return({
          total_hours: 85,
          hours_by_category: {},
          hours_by_source: { external: 85, activity: 0 },
          external_hourly_activity_ids: [],
          activity_ids: []
        })
      end

      it "marks task as completed" do
        patch review_activity_report_task_url(task), params: approve_params

        task.reload

        expect(task).to be_completed
      end

      it "marks case as approved and transitions to end" do
        patch review_activity_report_task_url(task), params: approve_params

        kase.reload

        expect(kase.activity_report_approval_status).to eq("approved")
        expect(kase.business_process_instance.current_step).to eq("end")
        expect(kase).to be_closed
      end

      it "records the approved outcome on the task and its application form" do
        patch review_activity_report_task_url(task), params: approve_params

        expect(task.reload.approval_status).to eq("approved")
        expect(task.application_form.approval_status).to eq("approved")
      end

      it "redirects back to the task" do
        patch review_activity_report_task_url(task), params: approve_params
        expect(response).to redirect_to(task_path(task))
      end

      it "logs to audit log" do
        expect do
          patch review_activity_report_task_url(task), params: approve_params
        end.to change { Strata::AuditLine.where(actor: user, subject: certification, action: 'case.activity_report.approved').count }.by(1)
      end
    end

    context "with not acceptable action" do
      let(:deny_params) { { review_activity_report_task: { activity_report_decision: "no-not-acceptable" } } }

      before do
        # Stub aggregate_hours_for_certification for the model's deny method
        allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_return({
          total_hours: 40,
          hours_by_category: {},
          hours_by_source: { external: 40, activity: 0 },
          external_hourly_activity_ids: [],
          activity_ids: []
        })
      end

      it "marks task as completed" do
        patch review_activity_report_task_url(task), params: deny_params
        task.reload

        expect(task).to be_completed
      end

      it "marks case as denied and returns to report_activities while the verification window is open" do
        patch review_activity_report_task_url(task), params: deny_params
        kase.reload

        expect(kase.activity_report_approval_status).to eq("denied")
        expect(kase.business_process_instance.current_step).to eq("report_activities")
        expect(kase).to be_open
      end

      context "when the verification window has ended" do
        before { kase.update_attribute(:verification_window_end_date, 1.day.ago) }

        it "marks case as denied and transitions to end (final denial)" do
          patch review_activity_report_task_url(task), params: deny_params
          kase.reload

          expect(kase.activity_report_approval_status).to eq("denied")
          expect(kase.business_process_instance.current_step).to eq("end")
          expect(kase).to be_closed
        end
      end

      it "records the denied outcome on the task and its application form" do
        patch review_activity_report_task_url(task), params: deny_params

        expect(task.reload.approval_status).to eq("denied")
        expect(task.application_form.approval_status).to eq("denied")
      end

      it "redirects back to the task" do
        patch review_activity_report_task_url(task), params: deny_params
        expect(response).to redirect_to(task_path(task))
      end

      it "logs to audit log" do
        expect do
          patch review_activity_report_task_url(task), params: deny_params
        end.to change { Strata::AuditLine.where(actor: user, subject: certification, action: 'case.activity_report.denied').count }.by(1)
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

    it "renders :unprocessable_content when staff_comment is blank" do
      form_params  =  { activity_report_information_request: { staff_comment: "" } }
      expect {
        post create_information_request_review_activity_report_task_path(task), params: form_params
      }.not_to change(ActivityReportInformationRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)

      task.reload
      expect(task).to be_pending
    end
  end
end
