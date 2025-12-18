# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/exemption_application_forms", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }
  let(:certification) { create(:certification) }
  let(:certification_case) { create(:certification_case, certification: certification) }
  let(:valid_attributes) {
    {
      exemption_type: "short_term_hardship",
      certification_case_id: certification_case.id
    }
  }

  let(:existing_exemption_application_form) { create(:exemption_application_form, user_id: user.id) }

  let(:invalid_attributes) {
    {
      exemption_type: "Super Rare Exemption Type"
    }
  }

  before do
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "GET /show" do
    it "renders a successful response" do
      get exemption_application_form_url(existing_exemption_application_form)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_exemption_application_form_url(certification_case_id: certification_case.id)
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders the exemption type selection page" do
      get edit_exemption_application_form_url(existing_exemption_application_form)
      expect(response).to be_successful
      expect(response.body).to include("What type of exemption are you requesting?")
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new ExemptionApplicationForm" do
        expect {
          post exemption_application_forms_url, params: { exemption_application_form: valid_attributes }
        }.to change(ExemptionApplicationForm, :count).by(1)
      end

      it "redirects to the exemption type selection page" do
        post exemption_application_forms_url, params: { exemption_application_form: valid_attributes }
        expect(response).to redirect_to(edit_exemption_application_form_path(ExemptionApplicationForm.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new ExemptionApplicationForm" do
        expect {
          post exemption_application_forms_url, params: { exemption_application_form: invalid_attributes }
        }.not_to change(ExemptionApplicationForm, :count)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post exemption_application_forms_url, params: { exemption_application_form: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not create a duplicate exemption form with the same certification_case_id" do
        create(:exemption_application_form, certification_case_id: valid_attributes[:certification_case_id], user_id: user.id)

        expect {
          post exemption_application_forms_url, params: { exemption_application_form: valid_attributes }
        }.not_to change(ExemptionApplicationForm, :count)
      end

      it "redirects to dashboard with notice when attempting to create duplicate by certification_case_id" do
        create(:exemption_application_form, certification_case_id: valid_attributes[:certification_case_id], user_id: user.id)

        post exemption_application_forms_url, params: { exemption_application_form: valid_attributes }
        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(response.body).to include("An exemption application already exists for this certification case")
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) {
        { exemption_type: "incarceration" }
      }

      it "updates the requested exemption_application_form" do
        exemption_application_form = create(:exemption_application_form, user_id: user.id, exemption_type: "short_term_hardship")
        patch exemption_application_form_url(exemption_application_form), params: { exemption_application_form: new_attributes }
        expect(exemption_application_form.reload.exemption_type).to eq("incarceration")
      end

      it "redirects to the documents page" do
        patch exemption_application_form_url(existing_exemption_application_form), params: { exemption_application_form: new_attributes }
        existing_exemption_application_form.reload
        expect(response).to redirect_to(documents_exemption_application_form_path(existing_exemption_application_form))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'exemption_type' template)" do
        patch exemption_application_form_url(existing_exemption_application_form), params: { exemption_application_form: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested exemption_application_form" do
      form = create(:exemption_application_form, user_id: user.id)
      expect {
        delete exemption_application_form_url(form)
      }.to change(ExemptionApplicationForm, :count).by(-1)
    end

    it "redirects to the dashboard" do
      delete exemption_application_form_url(existing_exemption_application_form)
      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "GET /review" do
    it "renders a successful response" do
      get review_exemption_application_form_url(existing_exemption_application_form)
      expect(response).to be_successful
    end
  end

  describe "POST /submit" do
    it "marks the activity report as submitted" do
      post submit_exemption_application_form_url(existing_exemption_application_form)

      existing_exemption_application_form.reload
      expect(existing_exemption_application_form).to be_submitted
    end

    it "redirects to GET /show on success" do
      post submit_exemption_application_form_url(existing_exemption_application_form)

      expect(response).to redirect_to(exemption_application_form_url(existing_exemption_application_form))
    end
  end

  describe "GET /documents" do
    it "renders a successful response" do
      get documents_exemption_application_form_url(existing_exemption_application_form)
      expect(response).to be_successful
    end
  end


  describe "POST /upload_documents" do
    let(:file) do
      fixture_file_upload(
        Rails.root.join(
          'spec',
          'fixtures',
          'files',
          'test_document_1.pdf'
        ),
        'application/pdf'
      )
    end

    context "when the user is authorized" do
      it "uploads the document successfully" do
        post upload_documents_exemption_application_form_path(existing_exemption_application_form),
          params: { exemption_application_form: { supporting_documents: [file] } }
        expect(response).to redirect_to(documents_exemption_application_form_path(existing_exemption_application_form))
        follow_redirect!
        expect(response).to have_http_status(:ok)
        expect(existing_exemption_application_form.reload.supporting_documents.attached?).to be true
      end
    end
  end
end
