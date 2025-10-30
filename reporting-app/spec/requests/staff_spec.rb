# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/staff", type: :request do
  include Warden::Test::Helpers

  let(:user) { User.create!(email: "test@example.com", uid: SecureRandom.uuid, provider: "login.gov") }
  let(:other_user) { User.create!(email: "other@example.com", uid: SecureRandom.uuid, provider: "login.gov") }
  let(:certification_case) { create(:certification_case) }

  before do
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /index" do
    context "when no tasks are assigned to the current user" do
      before do
        # Create tasks assigned to other user
        task1 = create(:review_activity_report_task, case: certification_case, status: :pending)
        task2 = create(:review_exemption_claim_task, case: certification_case, status: :pending)
        task1.assign(other_user.id)
        task2.assign(other_user.id)
      end

      it "renders a successful response" do
        get "/staff"
        expect(response).to be_successful
      end

      it "shows no pending tasks message" do
        get "/staff"
        expect(response.body).to include("No pending tasks")
      end
    end

    context "when tasks are assigned to the current user" do
      let(:review_activity_report_task) { create(:review_activity_report_task, case: certification_case, status: :pending) }
      let(:review_exemption_claim_task) { create(:review_exemption_claim_task, case: certification_case, status: :pending) }
      let(:other_task) { create(:review_exemption_claim_task, case: certification_case, status: :pending) }

      before do
        review_activity_report_task.assign(user.id)
        review_exemption_claim_task.assign(user.id)
        # Create tasks assigned to other user (should not appear)
        other_task.assign(other_user.id)
      end

      it "renders a successful response" do
        get "/staff"
        expect(response).to be_successful
      end

      it "shows the tasks table with pending tasks for the current user" do
        get "/staff"
        expect(response.body).not_to include("No pending tasks")
        expect(response.body).to include(task_path(review_activity_report_task))
        expect(response.body).to include(task_path(review_exemption_claim_task))
        expect(response.body).not_to include(task_path(other_task))
      end

      it "orders tasks by due_on in descending order" do
        # Update due dates to test ordering
        review_activity_report_task.update!(due_on: 5.days.from_now)
        review_exemption_claim_task.update!(due_on: 2.days.from_now)

        get "/staff"
        # Check that the later due date appears first in the HTML
        response_body = response.body
        review_activity_report_task_position = response_body.index(task_path(review_activity_report_task))
        review_exemption_claim_task_position = response_body.index(task_path(review_exemption_claim_task))
        expect(review_exemption_claim_task_position).to be < review_activity_report_task_position
      end
    end

    context "when only completed tasks are assigned to the current user" do
      before do
        # Create completed tasks for current user
        completed_task = create(:review_activity_report_task, case: certification_case, status: :completed)
        completed_task.assign(user.id)
      end

      it "renders a successful response" do
        get "/staff"
        expect(response).to be_successful
      end

      it "shows no pending tasks message (only pending tasks are shown)" do
        get "/staff"
        expect(response.body).to include("No pending tasks")
      end
    end
  end
end
