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
