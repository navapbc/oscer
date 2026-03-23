# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/staff/tasks", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user, :as_caseworker, region: "Southeast") }
  let(:certification) { create(:certification, certification_requirements: build(:certification_certification_requirements, region: "Southeast")) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }

  before do
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /show" do
    context "with ActivityReportApplicationForm" do
      let(:activity_report_application_form) { create(:activity_report_application_form, certification_case_id: certification_case.id, user_id: user.id) }
      let(:activity_report_task) { create(:review_activity_report_task, case: certification_case) }

      before { activity_report_application_form.save! }

      it "renders a successful response with the task information" do
        get "/staff/tasks/#{activity_report_task.id}"
        expect(response).to be_successful
        expect(response.body).to include(activity_report_task.id)
      end

      context "with work activities" do
        let(:work_activity) do
          create(
            :work_activity,
            activity_report_application_form_id: activity_report_application_form.id,
            category: "employment",
            hours: 40
          )
        end

        before { work_activity }

        it "displays activity category and hours" do
          get "/staff/tasks/#{activity_report_task.id}"

          expect(response.body).to include("Employment")
          expect(response.body).to include("40")
        end
      end

      context "with income activities" do
        let(:income_activity) do
          create(
            :income_activity,
            activity_report_application_form_id: activity_report_application_form.id,
            category: "employment",
            income: 150_000
          )
        end

        before { income_activity }

        it "displays activity category and formatted income" do
          get "/staff/tasks/#{activity_report_task.id}"

          expect(response.body).to include("Employment")
          expect(response.body).to include("$1,500")
        end
      end

      context "with activities that have supporting documents" do
        let(:activity) do
          create(
            :work_activity,
            activity_report_application_form_id: activity_report_application_form.id
          )
        end

        before do
          activity.supporting_documents.attach(
            fixture_file_upload("spec/fixtures/files/test_document_1.pdf", "application/pdf")
          )
        end

        it "displays document links" do
          get "/staff/tasks/#{activity_report_task.id}"

          expect(response.body).to include("test_document_1.pdf")
          expect(response.body).to include("usa-link")
        end

        it "renders the document preview panel with Stimulus targets" do
          with_doc_ai_enabled do
            get "/staff/tasks/#{activity_report_task.id}"

            expect(response.body).to include('data-controller="document-preview"')
            expect(response.body).to include('data-document-preview-target="previewArea"')
            expect(response.body).to include('data-document-preview-target="table"')
            expect(response.body).to include('data-action="document-preview#select"')
            expect(response.body).to include('aria-label="Preview test_document_1.pdf"')
            expect(response.body).to include(I18n.t("activity_report_application_forms.staff_activity_report.preview"))
          end
        end

        it "renders the prefill form with close button for the activity" do
          with_doc_ai_enabled do
            get "/staff/tasks/#{activity_report_task.id}"

            expect(response.body).to include('data-document-preview-target="prefillForm"')
            expect(response.body).to include("data-activity-id=\"#{activity.id}\"")
            expect(response.body).to include(activity.name)
            expect(response.body).to include('data-action="document-preview#close"')
          end
        end

        it "renders document links without preview panel when doc_ai is disabled" do
          with_doc_ai_disabled do
            get "/staff/tasks/#{activity_report_task.id}"

            expect(response.body).to include("test_document_1.pdf")
            expect(response.body).to include("usa-link")
            expect(response.body).not_to include('data-controller="document-preview"')
          end
        end
      end

      context "with mixed activities (some with documents, some without)" do
        let(:activity_with_doc) do
          create(
            :work_activity,
            activity_report_application_form_id: activity_report_application_form.id,
            name: "Documented Work"
          )
        end
        let(:activity_without_doc) do
          create(
            :work_activity,
            activity_report_application_form_id: activity_report_application_form.id,
            name: "Undocumented Work"
          )
        end

        before do
          activity_with_doc.supporting_documents.attach(
            fixture_file_upload("spec/fixtures/files/test_document_1.pdf", "application/pdf")
          )
          activity_without_doc
        end

        it "renders prefill form only for activity with documents" do
          with_doc_ai_enabled do
            get "/staff/tasks/#{activity_report_task.id}"

            expect(response.body).to include("data-activity-id=\"#{activity_with_doc.id}\"")
            expect(response.body).to include("Documented Work")
            expect(response.body).to include("Undocumented Work")
            expect(response.body).not_to include("data-activity-id=\"#{activity_without_doc.id}\"")
          end
        end
      end

      context "with activities that have no supporting documents" do
        let(:activity) do
          create(
            :work_activity,
            activity_report_application_form_id: activity_report_application_form.id
          )
        end

        before { activity }

        it "displays the no documents message" do
          get "/staff/tasks/#{activity_report_task.id}"

          expect(response.body).to include(I18n.t("activity_report_application_forms.staff_activity_report.no_documents"))
        end

        it "renders the activity table without preview panel when doc_ai is enabled" do
          with_doc_ai_enabled do
            get "/staff/tasks/#{activity_report_task.id}"

            expect(response.body).to include(activity.name)
            expect(response.body).not_to include('data-document-preview-target="previewArea"')
          end
        end
      end
    end

    context "with ExemptionApplicationForm" do
      let(:exemption_application_form) { create(:exemption_application_form, certification_case_id: certification_case.id, user_id: user.id) }
      let(:exemption_task) { create(:review_exemption_claim_task, case: certification_case) }

      before { exemption_application_form.save! }

      it "renders a successful response with the task information" do
        get "/staff/tasks/#{exemption_task.id}"
        expect(response).to be_successful
        expect(response.body).to include(exemption_task.id)
      end
    end

    context "with both an ActivityReportApplicationForm and an ExemptionApplicationForm" do
      let(:activity_report_task) { create(:review_activity_report_task, case: certification_case) }
      let(:exemption_task) { create(:review_exemption_claim_task, case: certification_case) }
      let(:exemption_application_form) { build(:exemption_application_form, certification_case_id: certification_case.id) }
      let(:activity_report_application_form) { build(:activity_report_application_form, certification_case_id: certification_case.id) }

      before do
        activity_report_application_form.save!
        exemption_application_form.save!
      end

      it "renders a successful response with the activity report task information" do
        get "/staff/tasks/#{activity_report_task.id}"
        expect(response).to be_successful
        expect(response.body).to include(activity_report_task.id)
      end

      it "renders a successful response with the exemption task information" do
        get "/staff/tasks/#{exemption_task.id}"
        expect(response).to be_successful
        expect(response.body).to include(exemption_task.id)
      end
    end
  end

  describe "GET /show with doc_ai" do
    let(:activity_report_application_form) { create(:activity_report_application_form, certification_case_id: certification_case.id, user_id: user.id) }
    let(:activity_report_task) { create(:review_activity_report_task, case: certification_case) }

    before do
      activity_report_application_form.save!
    end

    context "when doc_ai is enabled" do
      it "renders confidence column for ai_sourced activity" do
        activity = activity_report_application_form.activities.create!(
          name: "AI Employer",
          type: "IncomeActivity",
          income: 200_000,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "ai_assisted"
        )
        ai_user = create(:user)
        create(:staged_document, :validated,
          stageable: activity,
          user_id: ai_user.id,
          extracted_fields: { "grosspay" => { "confidence" => 0.91, "value" => 2000 } })

        with_doc_ai_enabled do
          get "/staff/tasks/#{activity_report_task.id}"
          expect(response).to be_successful
          expect(response.body).to include("Confidence Level")
          expect(response.body).to include("91%")
        end
      end

      it "shows evidence source icon" do
        activity_report_application_form.activities.create!(
          name: "Manual Employer",
          type: "WorkActivity",
          hours: 20,
          month: Date.current.beginning_of_month,
          category: "employment",
          evidence_source: "self_reported"
        )

        with_doc_ai_enabled do
          get "/staff/tasks/#{activity_report_task.id}"
          expect(response).to be_successful
          expect(response.body).to include("#person")
        end
      end
    end

    context "when doc_ai is disabled" do
      it "does not show confidence column" do
        activity_report_application_form.activities.create!(
          name: "Some Employer",
          type: "WorkActivity",
          hours: 30,
          month: Date.current.beginning_of_month,
          category: "employment"
        )

        with_doc_ai_disabled do
          get "/staff/tasks/#{activity_report_task.id}"
          expect(response).to be_successful
          expect(response.body).not_to include("Confidence Level")
        end
      end
    end
  end

  describe "GET /index" do
    let(:pending_task) { build(:review_activity_report_task, case: certification_case, status: :pending) }
    let(:completed_task) { build(:review_activity_report_task, case: certification_case, status: :completed) }
    let(:on_hold_task) { build(:review_activity_report_task, case: certification_case, status: :on_hold) }

    before do
      pending_task.save!
      completed_task.save!
      on_hold_task.save!
    end

    context "when filtering by pending status" do
      before do
        get "/staff/tasks", params: { filter_status: "pending" }
      end

      it "includes only pending tasks" do
        expect(response.body).to include(pending_task.id)
        expect(response.body).not_to include(completed_task.id)
        expect(response.body).not_to include(on_hold_task.id)
      end
    end

    context "when filtering by completed status" do
      before do
        get "/staff/tasks", params: { filter_status: "completed" }
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "includes only completed tasks" do
        expect(response.body).not_to include(pending_task.id)
        expect(response.body).to include(completed_task.id)
        expect(response.body).not_to include(on_hold_task.id)
      end
    end

    context "when filtering by on_hold status" do
      before do
        get "/staff/tasks", params: { filter_status: "on_hold" }
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "includes only on_hold tasks" do
        expect(response.body).not_to include(pending_task.id)
        expect(response.body).not_to include(completed_task.id)
        expect(response.body).to include(on_hold_task.id)
      end
    end

    context "when no status parameter is provided" do
      before do
        get "/staff/tasks"
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "defaults to showing pending tasks" do
        expect(response.body).to include(pending_task.id)
        expect(response.body).not_to include(completed_task.id)
        expect(response.body).not_to include(on_hold_task.id)
      end
    end

    context "with doc_ai feature flag" do
      context "when doc_ai is enabled" do
        it "shows confidence column header" do
          with_doc_ai_enabled do
            get "/staff/tasks", params: { filter_status: "pending" }
            expect(response.body).to include("Confidence level")
          end
        end

        it "renders confidence percentage when DocAI data exists" do
          form = create(:activity_report_application_form, certification_case_id: certification_case.id)
          activity = form.activities.create!(
            name: "AI Co",
            type: "IncomeActivity",
            income: 200_000,
            month: Date.current.beginning_of_month,
            category: "employment",
            evidence_source: "ai_assisted"
          )
          ai_user = create(:user)
          create(:staged_document, :validated,
            stageable: activity,
            user_id: ai_user.id,
            extracted_fields: { "grosspay" => { "confidence" => 0.85, "value" => 1000 } })

          with_doc_ai_enabled do
            get "/staff/tasks", params: { filter_status: "pending" }
            expect(response.body).to include("85%")
          end
        end

        it "highlights row with bg-error-lighter for low confidence" do
          form = create(:activity_report_application_form, certification_case_id: certification_case.id)
          activity = form.activities.create!(
            name: "Low AI Co",
            type: "IncomeActivity",
            income: 200_000,
            month: Date.current.beginning_of_month,
            category: "employment",
            evidence_source: "ai_assisted"
          )
          ai_user = create(:user)
          create(:staged_document, :validated,
            stageable: activity,
            user_id: ai_user.id,
            extracted_fields: { "grosspay" => { "confidence" => 0.55, "value" => 500 } })

          with_doc_ai_enabled do
            get "/staff/tasks", params: { filter_status: "pending" }
            expect(response.body).to include("bg-error-lighter")
            expect(response.body).to include("55%")
          end
        end
      end

      context "when doc_ai is disabled" do
        it "does not show confidence column" do
          with_doc_ai_disabled do
            get "/staff/tasks", params: { filter_status: "pending" }
            expect(response.body).not_to include("Confidence level")
          end
        end
      end
    end
  end

  describe "POST /pick_up_next_task" do
    context "when there is an unassigned task in the user's region" do
      let(:unassigned_task) { create(:review_activity_report_task, case: certification_case) }

      before { unassigned_task }

      it "assigns the task to the user" do
        expect {
          post "/staff/tasks/pick_up_next_task"
        }.to change { unassigned_task.reload.assignee_id }.from(nil).to(user.id)
      end

      it "redirects to the task show page" do
        post "/staff/tasks/pick_up_next_task"
        expect(response).to redirect_to(task_path(unassigned_task))
      end

      it "sets a success flash message" do
        post "/staff/tasks/pick_up_next_task"
        expect(flash["task-message"]).to eq(I18n.t("strata.tasks.messages.task_picked_up"))
      end
    end

    context "when there are no unassigned tasks in the user's region" do
      before do
        # Create a completed task (not unassigned)
        create(:review_activity_report_task, case: certification_case, status: :completed)
      end

      it "does not assign any task" do
        post "/staff/tasks/pick_up_next_task"
        expect(Strata::Task.where(assignee_id: user.id)).to be_empty
      end

      it "redirects to the tasks index" do
        post "/staff/tasks/pick_up_next_task"
        expect(response).to redirect_to(tasks_path)
      end

      it "sets a 'no tasks available' flash message" do
        post "/staff/tasks/pick_up_next_task"
        expect(flash["task-message"]).to eq(I18n.t("strata.tasks.messages.no_tasks_available"))
      end
    end

    context "when there is an unassigned task in a different region" do
      let(:other_region) { "Northeast" }
      let(:other_certification) do
        create(
          :certification,
          certification_requirements: build(:certification_certification_requirements, region: other_region)
        )
      end
      let(:other_certification_case) { create(:certification_case, certification_id: other_certification.id) }
      let(:other_region_task) { create(:review_activity_report_task, case: other_certification_case) }

      before { other_region_task }

      it "does not assign the task from the other region" do
        post "/staff/tasks/pick_up_next_task"
        expect(other_region_task.reload.assignee_id).to be_nil
      end

      it "redirects to the tasks index" do
        post "/staff/tasks/pick_up_next_task"
        expect(response).to redirect_to(tasks_path)
      end

      it "sets a 'no tasks available' flash message" do
        post "/staff/tasks/pick_up_next_task"
        expect(flash["task-message"]).to eq(I18n.t("strata.tasks.messages.no_tasks_available"))
      end
    end

    context "when there are multiple unassigned tasks in the user's region" do
      let(:first_task) { create(:review_activity_report_task, case: certification_case, due_on: 1.day.from_now) }
      let(:second_task) { create(:review_activity_report_task, case: certification_case, due_on: 2.days.from_now) }

      before do
        first_task
        second_task
      end

      it "assigns the first task (by due date)" do
        post "/staff/tasks/pick_up_next_task"
        expect(first_task.reload.assignee_id).to eq(user.id)
        expect(second_task.reload.assignee_id).to be_nil
      end
    end
  end
end
