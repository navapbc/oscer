# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/activities", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }
  let(:activity_report_application_form) do
    create(
      :activity_report_application_form,
      :with_activities,
      user_id: user.id,
      reporting_periods: [ Strata::YearMonth.new(year: 2025, month: 1), Strata::YearMonth.new(year: 2025, month: 2) ]
    )
  end
  let(:existing_activity) { create(:work_activity, activity_report_application_form_id: activity_report_application_form.id) }

  before do
    login_as user
    existing_activity
  end

  after do
    Warden.test_reset!
  end

  describe "GET /show" do
    it "renders a successful response" do
      get activity_report_application_form_activity_url(activity_report_application_form, existing_activity)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_activity_report_application_form_activity_url(activity_report_application_form)
      expect(response).to be_successful
    end
  end

  describe "GET /new_activity" do
    context "when activity_type param is missing" do
      it "redirects to category selection with an alert message" do
        get new_activity_new_activity_report_application_form_activity_url(
          activity_report_application_form,
          category: "employment"
        )

        expect(response).to redirect_to(new_activity_report_application_form_activity_path(activity_report_application_form))
        expect(flash[:alert]).to eq("You must select a reporting method (hours or income) before continuing.")
      end
    end

    context "when activity_type param is provided directly" do
      it "renders the new activity form" do
        get new_activity_new_activity_report_application_form_activity_url(
          activity_report_application_form,
          category: "employment",
          activity_type: "work_activity"
        )

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      get edit_activity_report_application_form_activity_url(activity_report_application_form, existing_activity)
      expect(response).to be_successful
    end
  end

  describe "GET /documents" do
    it "renders a successful response" do
      get documents_activity_report_application_form_activity_url(activity_report_application_form, existing_activity)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "when activity type is work_activity" do
      context "without any hours" do
        let(:invalid_attributes) {
          {
            name: "Valid Name",
            activity_type: "work_activity",
            hours: ""
          }
        }

        it "does not create a new Activity" do
          expect {
            post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: invalid_attributes }
          }.not_to change(WorkActivity, :count)
        end

        it "renders a response with 422 status (unprocessable entity)" do
          post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "renders error messages" do
          post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: invalid_attributes }
          expect(response.body).to include("Hours must be greater than 0")
        end
      end

      context "with valid activity parameters" do
        it "creates a new WorkActivity when activity_type is work_activity" do
          valid_attributes = {
            name: Faker::Company.name,
            activity_type: "work_activity",
            hours: rand(1..79).to_s,
            month: (Date.today - 2.months).beginning_of_month,
            category: "employment"
          }

          expect {
            post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: valid_attributes }
          }.to change(WorkActivity, :count).from(1).to(2)
        end

        it "redirects to the activity report when type is work_activity" do
          valid_attributes = {
            name: Faker::Company.name,
            activity_type: "work_activity",
            hours: rand(1..79).to_s,
            month: (Date.today - 2.months).beginning_of_month,
            category: "employment"
          }

          post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: valid_attributes }

          expect(response).to have_http_status(:redirect)
          expect(response.location).to match(%r{/activity_report_application_forms/#{activity_report_application_form.id}/activities/[^/]+/documents})
        end

        it "preserves decimal hours" do
          valid_attributes = {
            name: Faker::Company.name,
            activity_type: "work_activity",
            hours: "5.25",
            month: (Date.today - 2.months).beginning_of_month,
            category: "employment"
          }

          post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: valid_attributes }

          created_activity = activity_report_application_form.activities.where(name: valid_attributes[:name]).first
          expect(created_activity.hours).to eq(5.25)
        end
      end
    end

    context "when activity type is income_activity" do
      context "without any income" do
        let(:invalid_attributes) {
          {
            name: "Valid Name",
            activity_type: "income_activity",
            income: "0"
          }
        }

        it "does not create a new Activity" do
          expect {
            post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: invalid_attributes }
          }.not_to change(IncomeActivity, :count)
        end

        it "renders a response with 422 status (unprocessable entity)" do
          post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "renders error messages" do
          post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: invalid_attributes }
          expect(response.body).to include("Income must be greater than 0")
        end
      end

      context "with valid activity parameters" do
        it "creates a new IncomeActivity when activity_type is income_activity" do
          valid_attributes = {
            name: Faker::Company.name,
            activity_type: "income_activity",
            income: rand(50..300).to_s,
            month: (Date.today - 2.months).beginning_of_month,
            category: "employment"
          }

          expect {
            post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: valid_attributes }
          }.to change(IncomeActivity, :count).by(1)
        end

        it "redirects to the activity report when type is income_activity" do
          valid_attributes = {
            name: Faker::Company.name,
            activity_type: "income_activity",
            income: rand(1..79).to_s,
            month: (Date.today - 2.months).beginning_of_month,
            category: "employment"
          }

          post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: valid_attributes }

          expect(response).to have_http_status(:redirect)
          expect(response.location).to match(%r{/activity_report_application_forms/#{activity_report_application_form.id}/activities/[^/]+/documents})
        end
      end
    end

    context "without a name" do
      let(:invalid_attributes) {
        {
          name: "",
          activity_type: "work_activity",
          hours: "23"
        }
      }

      it "does not create a new Activity" do
        expect {
          post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: invalid_attributes }
        }.not_to change(Activity, :count)
      end

      it "renders a response with 422 status (unprocessable entity)" do
        post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "renders error messages" do
        post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: invalid_attributes }
        expect(response.body).to include("Name can&#39;t be blank")
      end
    end

    context "with category persisted" do
      it "persists the category on the created activity" do
        valid_attributes = {
          name: Faker::Company.name,
          activity_type: "work_activity",
          hours: rand(1..79).to_s,
          month: (Date.today - 2.months).beginning_of_month,
          category: "education"
        }

        expect {
          post activity_report_application_form_activities_url(activity_report_application_form), params: { activity: valid_attributes }
        }.to change(WorkActivity, :count).by(1)

        created_activity = activity_report_application_form.activities.where(name: valid_attributes[:name]).first
        expect(created_activity.category).to eq("education")
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) {
        {
          name: "New Employer Corp",
          hours: 100.0
        }
      }

      before do
        patch activity_report_application_form_activity_url(activity_report_application_form, existing_activity), params: { activity: new_attributes }
      end

      it "updates the requested activity" do
        activity_report_application_form.reload
        updated_activity = activity_report_application_form.activities_by_id[existing_activity.id]
        expect(updated_activity.name).to eq("New Employer Corp")
        expect(updated_activity.hours).to eq(100.0)
      end

      it "redirects to the activity report" do
        expect(response).to redirect_to(documents_activity_report_application_form_activity_url(activity_report_application_form, existing_activity))
      end
    end

    context "with decimal hours" do
      it "preserves decimal values" do
        patch activity_report_application_form_activity_url(activity_report_application_form, existing_activity),
          params: { activity: { hours: "3.5" } }

        activity_report_application_form.reload
        updated_activity = activity_report_application_form.activities_by_id[existing_activity.id]
        expect(updated_activity.hours).to eq(3.5)
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (unprocessable entity)" do
        patch activity_report_application_form_activity_url(activity_report_application_form, existing_activity), params: { activity: { activity_type: "not_accurate_type", hours: "Not a number", name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "renders an error if the name is blank" do
        invalid_attributes = { name: "", activity_type: "work_activity", hours: "23" }
        patch activity_report_application_form_activity_url(activity_report_application_form, existing_activity), params: { activity: invalid_attributes }
        expect(response.body).to include("Name can&#39;t be blank")
      end

      it "does not update the activity" do
        activity_report_application_form.reload
        updated_activity = activity_report_application_form.activities_by_id[existing_activity.id]
        expect(updated_activity.name).not_to eq("")
        expect(updated_activity.hours).not_to eq("Not a number")
      end
    end
  end

  describe "PATCH /update with doc_ai_review" do
    let(:income_activity) do
      activity = IncomeActivity.new(
        activity_report_application_form_id: activity_report_application_form.id,
        category: "employment",
        evidence_source: "ai_assisted",
        month: Date.new(2025, 1, 1),
        income: 150_000
      )
      activity.save!(validate: false)
      activity
    end
    let(:second_activity) do
      activity = IncomeActivity.new(
        activity_report_application_form_id: activity_report_application_form.id,
        category: "employment",
        evidence_source: "ai_assisted",
        month: Date.new(2025, 2, 1),
        income: 200_000
      )
      activity.save!(validate: false)
      activity
    end

    context "with pending_review_ids" do
      it "redirects to the next activity edit page" do
        patch activity_report_application_form_activity_url(activity_report_application_form, income_activity),
          params: {
            activity: { name: "Acme Corp", income: "1500", month: Date.new(2025, 1, 1) },
            doc_ai_review: "true",
            pending_review_ids: [ second_activity.id ]
          }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(second_activity.id)
        expect(response.location).to include("doc_ai_review=true")
      end

      [ "1", "t", "T", "true", "TRUE", "on", "ON", "yes", "YES" ].each do |truthy_value|
        it "redirects to the next activity edit page when doc_ai_review is '#{truthy_value}'" do
          patch activity_report_application_form_activity_url(activity_report_application_form, income_activity),
            params: {
              activity: { name: "Acme Corp", income: "1500", month: Date.new(2025, 1, 1) },
              doc_ai_review: truthy_value,
              pending_review_ids: [ second_activity.id ]
            }

          expect(response).to have_http_status(:redirect)
          expect(response.location).to include(second_activity.id)
          expect(response.location).to include("doc_ai_review=true")
        end
      end
    end

    context "without pending_review_ids" do
      it "redirects to the activity report show page" do
        patch activity_report_application_form_activity_url(activity_report_application_form, income_activity),
          params: {
            activity: { name: "Acme Corp", income: "1500", month: Date.new(2025, 1, 1) },
            doc_ai_review: "true"
          }

        expect(response).to redirect_to(activity_report_application_form_url(activity_report_application_form))
      end
    end

    context "with evidence_source tracking" do
      it "keeps evidence_source as ai_assisted when income and month are unchanged" do
        patch activity_report_application_form_activity_url(activity_report_application_form, income_activity),
          params: {
            activity: { name: "Acme Corp", income: "1500", month: Date.new(2025, 1, 1) },
            doc_ai_review: "true"
          }

        income_activity.reload
        expect(income_activity.evidence_source).to eq("ai_assisted")
      end

      it "sets evidence_source to ai_assisted_with_member_edits when income differs" do
        patch activity_report_application_form_activity_url(activity_report_application_form, income_activity),
          params: {
            activity: { name: "Acme Corp", income: "2000", month: Date.new(2025, 1, 1) },
            doc_ai_review: "true"
          }

        income_activity.reload
        expect(income_activity.evidence_source).to eq("ai_assisted_with_member_edits")
      end

      it "sets evidence_source to ai_assisted_with_member_edits when month differs" do
        patch activity_report_application_form_activity_url(activity_report_application_form, income_activity),
          params: {
            activity: { name: "Acme Corp", income: "1500", month: Date.new(2025, 2, 1) },
            doc_ai_review: "true"
          }

        income_activity.reload
        expect(income_activity.evidence_source).to eq("ai_assisted_with_member_edits")
      end
    end

    context "without doc_ai_review param" do
      it "preserves existing redirect behavior" do
        patch activity_report_application_form_activity_url(activity_report_application_form, income_activity),
          params: {
            activity: { name: "Acme Corp", income: "1500", month: Date.new(2025, 1, 1) }
          }

        expect(response).to redirect_to(
          documents_activity_report_application_form_activity_url(activity_report_application_form, income_activity)
        )
      end
    end
  end

  describe "POST /upload_document" do
    let(:supporting_documents) { [
      fixture_file_upload('spec/fixtures/files/test_document_1.pdf', 'application/pdf'),
      fixture_file_upload('spec/fixtures/files/test_document_2.txt', 'text/plain')
    ] }

    before do
      post upload_documents_activity_report_application_form_activity_url(activity_report_application_form, existing_activity),
        params: { activity: { supporting_documents: supporting_documents } }
    end

    it "redirects back to the documents page" do
      expect(response).to redirect_to(documents_activity_report_application_form_activity_url(activity_report_application_form, existing_activity))
    end

    it "uploads the documents" do
      existing_activity.reload
      expect(existing_activity.supporting_documents.count).to eq(2)
    end

    it "sets a success flash notice" do
      expect(flash[:notice]).to eq(I18n.t("supporting_documents.upload_success"))
    end
  end

  describe "POST /upload_document when no new file is submitted" do
    it "does not set a success flash when params carry only signed_id strings from prior attachments" do
      existing_activity.supporting_documents.attach(
        fixture_file_upload('spec/fixtures/files/test_document_1.pdf', 'application/pdf')
      )
      existing_activity.save!
      signed_ids = existing_activity.supporting_documents.map(&:signed_id)

      post upload_documents_activity_report_application_form_activity_url(activity_report_application_form, existing_activity),
        params: { activity: { supporting_documents: signed_ids } }

      expect(flash[:notice]).to be_nil
    end

    it "does not set a success flash when supporting_documents is an empty array" do
      post upload_documents_activity_report_application_form_activity_url(activity_report_application_form, existing_activity),
        params: { activity: { supporting_documents: [] } }

      expect(flash[:notice]).to be_nil
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested activity" do
      expect {
        delete activity_report_application_form_activity_url(activity_report_application_form, existing_activity)
      }.to change(Activity, :count).by(-1)
    end

    it "redirects to the activities list" do
      delete activity_report_application_form_activity_url(activity_report_application_form, existing_activity)
      expect(response).to redirect_to(activity_report_application_form_url(activity_report_application_form))
    end
  end
end
