# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Staff::CertificationBatchUploads", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }

  before do
    login_as user
  end

  describe "GET /staff/staff/certification_batch_uploads/new" do
    it "renders the upload form" do
      get new_certification_batch_upload_path

      expect(response).to be_successful
      expect(response.body).to include("Upload Certification Roster")
    end
  end

  describe "POST /staff/staff/certification_batch_uploads" do
    context "with valid CSV file" do
      let(:csv_content) do
        <<~CSV
          member_id,case_number,member_email,first_name,last_name,certification_date,certification_type
          M127,C-007,test@example.com,Test,User,2025-01-15,new_application
        CSV
      end
      let(:csv_file) do
        Tempfile.new([ 'test', '.csv' ]).tap do |file|
          file.write(csv_content)
          file.rewind
        end
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(csv_file.path, 'text/csv') }

      after do
        csv_file.close
        csv_file.unlink
      end

      it "creates batch upload record and redirects to queue" do
        expect {
          post certification_batch_uploads_path, params: { csv_file: uploaded_file }
        }.to change(CertificationBatchUpload, :count).by(1)

        expect(response).to redirect_to(certification_batch_uploads_path)
        expect(flash[:notice]).to include("uploaded successfully")
      end

      it "attaches the file" do
        post certification_batch_uploads_path, params: { csv_file: uploaded_file }

        batch_upload = CertificationBatchUpload.last
        expect(batch_upload.file).to be_attached
        expect(batch_upload.filename).to include("test")
        expect(batch_upload.filename).to end_with(".csv")
      end

      it "does not process immediately" do
        allow(Strata::EventManager).to receive(:publish)

        expect {
          post certification_batch_uploads_path, params: { csv_file: uploaded_file }
        }.not_to change(Certification, :count)
      end
    end

    context "without CSV file" do
      it "shows error and re-renders form" do
        post certification_batch_uploads_path, params: { csv_file: nil }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Upload Certification Roster")
        expect(flash[:alert]).to eq("Please select a CSV file to upload")
      end
    end
  end

  describe "GET /staff/staff/certification_batch_uploads/:id" do
    let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user) }

    it "shows batch upload details" do
      get certification_batch_upload_path(batch_upload)

      expect(response).to be_successful
      expect(response.body).to include(batch_upload.filename)
    end
  end

  describe "POST /staff/staff/certification_batch_uploads/:id/process_batch" do
    include ActiveJob::TestHelper

    context "when batch is pending" do
      let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user, status: :pending) }

      it "enqueues processing job" do
        expect {
          post process_batch_certification_batch_upload_path(batch_upload)
        }.to have_enqueued_job(ProcessCertificationBatchUploadJob).with(batch_upload.id)
      end

      it "redirects to queue with success message" do
        post process_batch_certification_batch_upload_path(batch_upload)

        expect(response).to redirect_to(certification_batch_uploads_path)
        expect(flash[:notice]).to include("Processing started")
      end
    end

    context "when batch is already processing" do
      let(:batch_upload) { create(:certification_batch_upload, uploaded_by: user, status: :processing) }

      it "shows error and redirects" do
        post process_batch_certification_batch_upload_path(batch_upload)

        expect(response).to redirect_to(certification_batch_upload_path(batch_upload))
        expect(flash[:alert]).to include("cannot be processed")
      end
    end
  end
end
