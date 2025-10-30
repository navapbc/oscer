# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/staff/tasks", type: :request do
  include Warden::Test::Helpers

  let(:user) { User.create!(email: "test@example.com", uid: SecureRandom.uuid, provider: "login.gov") }
  let(:certification) { create(:certification) }
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

    before do
      pending_task.save!
      completed_task.save!
    end

    context "when filtering by pending status" do
      before do
        get "/staff/tasks", params: { status: "pending" }
      end

      it "includes only pending tasks" do
        expect(response.body).to include(pending_task.id)
        expect(response.body).not_to include(completed_task.id)
      end
    end

    context "when filtering by completed status" do
      before do
        get "/staff/tasks", params: { filter_status: "completed" }
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "returns non-pending tasks" do
        expect(response.body).not_to include(pending_task.id)
        expect(response.body).to include(completed_task.id)
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
      end
    end
  end
end
