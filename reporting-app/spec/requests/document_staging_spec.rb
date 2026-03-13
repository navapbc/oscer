# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/document_staging", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }

  before do
    login_as user
  end

  after do
    Warden.test_reset!
  end

  describe "POST /document_staging" do
    let(:uploaded_file) do
      tempfile = Tempfile.new([ "payslip", ".pdf" ])
      tempfile.write("%PDF-1.4 test payslip")
      tempfile.rewind
      Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true, original_filename: "payslip.pdf")
    end

    let(:service) { instance_double(DocumentStagingService) }
    let(:staged_doc) { create(:staged_document, user_id: user.id, doc_ai_job_id: "abc-123") }

    before do
      allow(DocumentStagingService).to receive(:new).and_return(service)
      allow(service).to receive(:submit).and_return([ staged_doc ])
    end

    it "calls the service and redirects to the status page" do
      activity_report = create(:activity_report_application_form)
      post document_staging_path, params: {
        files: [ uploaded_file ],
        activity_report_application_form_id: activity_report.id
      }
      expect(response).to redirect_to(
        doc_ai_upload_status_document_staging_path(
          ids: [ staged_doc.id ],
          activity_report_application_form_id: activity_report.id
        )
      )
      expect(service).to have_received(:submit) do |args|
        expect(args[:files]).to be_an(Array)
        expect(args[:files].size).to eq(1)
        expect(args[:files].first.original_filename).to eq("payslip.pdf")
        expect(args[:user]).to eq(user)
      end
    end

    context "with existing_ids for aggregation" do
      let(:existing_doc) { create(:staged_document, :validated, user_id: user.id, doc_ai_job_id: "existing-1") }

      it "merges existing IDs with new document IDs in redirect" do
        activity_report = create(:activity_report_application_form)
        post document_staging_path, params: {
          files: [ uploaded_file ],
          activity_report_application_form_id: activity_report.id,
          existing_ids: [ existing_doc.id ]
        }
        expect(response).to redirect_to(
          doc_ai_upload_status_document_staging_path(
            ids: [ existing_doc.id, staged_doc.id ],
            activity_report_application_form_id: activity_report.id
          )
        )
      end
    end

    context "when no files are provided" do
      before do
        allow(service).to receive(:submit).and_return([])
      end

      it "redirects back to the upload page with a notice" do
        activity_report = create(:activity_report_application_form)
        post document_staging_path, params: { files: [], activity_report_application_form_id: activity_report.id }
        expect(response).to redirect_to(
          doc_ai_upload_activity_report_application_form_path(activity_report)
        )
        expect(flash[:notice]).to be_present
      end
    end

    context "when service raises a validation error" do
      before do
        allow(service).to receive(:submit)
          .and_raise(DocumentStagingService::ValidationError, "At least one file required")
      end

      it "renders an error response" do
        post document_staging_path, params: { files: [] }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /document_staging/doc_ai_upload_status" do
    let(:activity_report) { create(:activity_report_application_form) }
    let(:staged_doc) do
      create(:staged_document, user_id: user.id, doc_ai_job_id: "abc-123", status: "pending")
    end

    it "renders a successful response with valid staged document IDs" do
      get doc_ai_upload_status_document_staging_path, params: {
        ids: [ staged_doc.id ],
        activity_report_application_form_id: activity_report.id
      }
      expect(response).to be_successful
    end

    it "redirects when documents belong to another user" do
      other_user = create(:user)
      other_doc = create(:staged_document, user_id: other_user.id, doc_ai_job_id: "xyz-789")

      get doc_ai_upload_status_document_staging_path, params: {
        ids: [ other_doc.id ],
        activity_report_application_form_id: activity_report.id
      }
      expect(response).to redirect_to(
        doc_ai_upload_activity_report_application_form_path(id: activity_report.id)
      )
    end
  end

  describe "GET /document_staging/lookup" do
    let(:staged_doc) do
      create(:staged_document, user_id: user.id, doc_ai_job_id: "abc-123", status: "pending")
    end

    it "renders a successful response for the user's documents" do
      activity_report = create(:activity_report_application_form)
      get lookup_document_staging_path, params: {
        ids: [ staged_doc.id ],
        activity_report_application_form_id: activity_report.id
      }
      expect(response).to be_successful
    end

    it "redirects when documents belong to another user" do
      other_user = create(:user)
      other_doc = create(:staged_document, user_id: other_user.id, doc_ai_job_id: "xyz-789")
      activity_report = create(:activity_report_application_form)

      get lookup_document_staging_path, params: {
        ids: [ other_doc.id ],
        activity_report_application_form_id: activity_report.id
      }
      expect(response).to redirect_to(
        doc_ai_upload_activity_report_application_form_path(id: activity_report.id)
      )
    end

    context "when all documents are complete" do
      let(:staged_doc) do
        create(:staged_document, :validated, user_id: user.id, doc_ai_job_id: "abc-123")
      end

      it "renders the results partial" do
        activity_report = create(:activity_report_application_form)
        get lookup_document_staging_path, params: {
          ids: [ staged_doc.id ],
          activity_report_application_form_id: activity_report.id
        }
        expect(response).to be_successful
        expect(response.body).to include(I18n.t("document_staging.results.selected_files"))
      end
    end
  end
end
