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
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("%PDF-1.4 test payslip"),
        filename: "payslip.pdf",
        content_type: "application/pdf"
      )
    end

    let(:service) { instance_double(DocumentStagingService) }
    let(:staged_doc) { create(:staged_document, user_id: user.id, doc_ai_job_id: "abc-123") }

    before do
      allow(DocumentStagingService).to receive(:new).and_return(service)
      allow(service).to receive(:submit).and_return([ staged_doc ])
    end

    it "calls the service and renders a successful response" do
      post document_staging_path, params: { signed_ids: [ blob.signed_id ] }
      expect(response).to be_successful
      expect(service).to have_received(:submit).with(
        signed_ids: [ blob.signed_id ],
        user: user
      )
    end

    context "when service raises a validation error" do
      before do
        allow(service).to receive(:submit)
          .and_raise(DocumentStagingService::ValidationError, "At least one file required")
      end

      it "renders an error response" do
        post document_staging_path, params: { signed_ids: [] }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /document_staging/lookup" do
    let!(:staged_doc) do
      create(:staged_document, user_id: user.id, doc_ai_job_id: "abc-123", status: "pending")
    end

    it "renders a successful response for the user's documents" do
      get lookup_document_staging_path, params: { ids: [ staged_doc.id ] }
      expect(response).to be_successful
    end

    it "does not include documents belonging to another user" do
      other_user = create(:user)
      other_doc = create(:staged_document, user_id: other_user.id, doc_ai_job_id: "xyz-789")

      get lookup_document_staging_path, params: { ids: [ other_doc.id ] }
      expect(response).to be_successful
      expect(response.body).not_to include(other_doc.file.filename.to_s)
    end

    context "when all documents are complete" do
      let!(:staged_doc) do
        create(:staged_document, :validated, user_id: user.id, doc_ai_job_id: "abc-123")
      end

      it "renders the results partial" do
        get lookup_document_staging_path, params: { ids: [ staged_doc.id ] }
        expect(response).to be_successful
        expect(response.body).to include("successfully validated")
      end
    end
  end
end
