# frozen_string_literal: true

require 'rails_helper'
require 'support/query_count_matchers'

RSpec.describe "Staff::CertificationBatchUploads", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user, :as_admin) }

  before do
    login_as user
    # Prevent auto-triggering business process during test setup
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(HoursComplianceDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  describe "GET /staff/staff/certification_batch_uploads/new" do
    it "renders the upload form" do
      get new_certification_batch_upload_path

      expect(response).to be_successful
      expect(response.body).to include("Upload Certification Roster")
    end
  end

  describe "POST /staff/staff/certification_batch_uploads/presigned_url" do
    let(:adapter) { instance_double(Storage::S3Adapter) }

    before do
      Rails.application.config.storage_adapter = adapter
      allow(adapter).to receive(:generate_signed_upload_url) do |args|
        { url: "https://s3.example.com/presigned", key: args[:key] }
      end
    end

    after do
      Rails.application.config.storage_adapter = nil
    end

    context "when batch_upload_v2 feature flag is enabled" do
      it "returns presigned URL and key" do
        with_batch_upload_v2_enabled do
          post presigned_url_certification_batch_uploads_path, params: { filename: "test.csv" }, as: :json

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json["url"]).to eq("https://s3.example.com/presigned")
          expect(json["key"]).to match(%r{\Abatch-uploads/[0-9a-f-]{36}/test\.csv\z})
        end
      end

      it "requires authentication" do
        with_batch_upload_v2_enabled do
          logout
          post presigned_url_certification_batch_uploads_path, params: { filename: "test.csv" }, as: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      it "requires admin authorization" do
        with_batch_upload_v2_enabled do
          login_as create(:user, :as_caseworker)
          post presigned_url_certification_batch_uploads_path, params: { filename: "test.csv" }, as: :json
          expect(response).to redirect_to("/staff")
        end
      end

      it "rejects blank filename" do
        with_batch_upload_v2_enabled do
          post presigned_url_certification_batch_uploads_path, params: { filename: "" }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json["error"]).to include("required")
        end
      end

      it "rejects non-CSV filename" do
        with_batch_upload_v2_enabled do
          post presigned_url_certification_batch_uploads_path, params: { filename: "test.exe" }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json["error"]).to include("CSV")
        end
      end

      context "with malicious filenames" do
        it "sanitizes path traversal in filename" do
          with_batch_upload_v2_enabled do
            post presigned_url_certification_batch_uploads_path,
                 params: { filename: "../../etc/passwd.csv" },
                 as: :json

            expect(response).to have_http_status(:ok)
            # Should return sanitized filename without path components
            storage_key = JSON.parse(response.body)["key"]
            expect(storage_key).to match(%r{\Abatch-uploads/[0-9a-f-]{36}/passwd\.csv\z})
            expect(storage_key).not_to include("../")
          end
        end

        it "sanitizes filenames with null bytes" do
          with_batch_upload_v2_enabled do
            post presigned_url_certification_batch_uploads_path,
                 params: { filename: "test\x00.csv" },
                 as: :json

            expect(response).to have_http_status(:ok)
            storage_key = JSON.parse(response.body)["key"]
            expect(storage_key).not_to include("\x00")
          end
        end

        it "sanitizes filenames with spaces" do
          with_batch_upload_v2_enabled do
            post presigned_url_certification_batch_uploads_path,
                 params: { filename: "test file name.csv" },
                 as: :json

            expect(response).to have_http_status(:ok)
            storage_key = JSON.parse(response.body)["key"]
            expect(storage_key).to include("test_file_name.csv")
            expect(storage_key).not_to include(" ")
          end
        end

        it "handles excessively long filenames" do
          with_batch_upload_v2_enabled do
            long_filename = "a" * 300 + ".csv"
            post presigned_url_certification_batch_uploads_path,
                 params: { filename: long_filename },
                 as: :json

            expect(response).to have_http_status(:ok)
            storage_key = JSON.parse(response.body)["key"]
            filename_part = storage_key.split("/").last
            expect(filename_part.length).to be <= 255
          end
        end
      end
    end

    context "when batch_upload_v2 feature flag is disabled" do
      it "returns 404" do
        with_batch_upload_v2_disabled do
          post presigned_url_certification_batch_uploads_path, params: { filename: "test.csv" }, as: :json
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe "POST /staff/staff/certification_batch_uploads" do
    context "with v2 flow (feature flag enabled and storage_key present)" do
      let(:storage_key) { "batch-uploads/550e8400-e29b-41d4-a716-446655440000/test.csv" }
      let(:filename) { "test.csv" }
      let(:adapter) { instance_double(Storage::S3Adapter, object_exists?: true) }

      before do
        Rails.application.config.storage_adapter = adapter
      end

      after do
        Rails.application.config.storage_adapter = nil
      end

      it "creates batch upload using orchestrator" do
        with_batch_upload_v2_enabled do
          expect {
            post certification_batch_uploads_path, params: { storage_key: storage_key, filename: filename }
          }.to change(CertificationBatchUpload, :count).by(1)

          batch_upload = CertificationBatchUpload.last
          expect(batch_upload.storage_key).to eq(storage_key)
          expect(batch_upload.filename).to eq(filename)
          expect(batch_upload.source_type).to eq("ui")
        end
      end

      it "enqueues processing job" do
        with_batch_upload_v2_enabled do
          expect {
            post certification_batch_uploads_path, params: { storage_key: storage_key, filename: filename }
          }.to have_enqueued_job(ProcessCertificationBatchUploadJob)
        end
      end

      it "redirects to show page with success notice" do
        with_batch_upload_v2_enabled do
          post certification_batch_uploads_path, params: { storage_key: storage_key, filename: filename }

          batch_upload = CertificationBatchUpload.last
          expect(response).to redirect_to(certification_batch_upload_path(batch_upload))
          expect(flash[:notice]).to include("uploaded successfully")
        end
      end

      it "handles FileNotFoundError" do
        with_batch_upload_v2_enabled do
          allow(adapter).to receive(:object_exists?).and_return(false)

          post certification_batch_uploads_path, params: { storage_key: storage_key, filename: filename }

          expect(response).to redirect_to(new_certification_batch_upload_path)
          expect(flash[:alert]).to include("File not found")
        end
      end

      it "requires authentication" do
        with_batch_upload_v2_enabled do
          logout
          post certification_batch_uploads_path, params: { storage_key: storage_key, filename: filename }
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      it "requires admin authorization" do
        with_batch_upload_v2_enabled do
          login_as create(:user, :as_caseworker)
          post certification_batch_uploads_path, params: { storage_key: storage_key, filename: filename }
          expect(response).to redirect_to("/staff")
        end
      end

      context "with malicious storage_key" do
        it "rejects path traversal in storage_key" do
          with_batch_upload_v2_enabled do
            post certification_batch_uploads_path, params: {
              storage_key: "../../../etc/passwd",
              filename: "test.csv"
            }

            expect(response).to redirect_to(new_certification_batch_upload_path)
            expect(flash[:alert]).to include("Invalid")
          end
        end

        it "rejects storage_key with wrong prefix" do
          with_batch_upload_v2_enabled do
            post certification_batch_uploads_path, params: {
              storage_key: "wrong-prefix/test.csv",
              filename: "test.csv"
            }

            expect(response).to redirect_to(new_certification_batch_upload_path)
            expect(flash[:alert]).to include("Invalid")
          end
        end

        it "rejects storage_key with multiple path components" do
          with_batch_upload_v2_enabled do
            post certification_batch_uploads_path, params: {
              storage_key: "batch-uploads/uuid/subdir/test.csv",
              filename: "test.csv"
            }

            expect(response).to redirect_to(new_certification_batch_upload_path)
            expect(flash[:alert]).to include("Invalid")
          end
        end
      end
    end

    context "with v1 flow (feature flag disabled or file attachment)" do
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

      context "when feature flag is disabled" do
        it "creates batch upload record using ActiveStorage" do
          with_batch_upload_v2_disabled do
            expect {
              post certification_batch_uploads_path, params: { csv_file: uploaded_file }
            }.to change(CertificationBatchUpload, :count).by(1)

            expect(response).to redirect_to(certification_batch_uploads_path)
            expect(flash[:notice]).to include("uploaded successfully")
          end
        end

        it "attaches the file" do
          with_batch_upload_v2_disabled do
            post certification_batch_uploads_path, params: { csv_file: uploaded_file }

            batch_upload = CertificationBatchUpload.last
            expect(batch_upload.file).to be_attached
            expect(batch_upload.filename).to include("test")
            expect(batch_upload.filename).to end_with(".csv")
          end
        end

        it "does not process immediately" do
          with_batch_upload_v2_disabled do
            allow(Strata::EventManager).to receive(:publish)

            expect {
              post certification_batch_uploads_path, params: { csv_file: uploaded_file }
            }.not_to change(Certification, :count)
          end
        end
      end

      context "when feature flag is enabled but file attachment is provided" do
        it "uses v1 flow for backward compatibility" do
          with_batch_upload_v2_enabled do
            expect {
              post certification_batch_uploads_path, params: { csv_file: uploaded_file }
            }.to change(CertificationBatchUpload, :count).by(1)

            batch_upload = CertificationBatchUpload.last
            expect(batch_upload.file).to be_attached
            expect(batch_upload.storage_key).to be_nil
          end
        end
      end

      context "without CSV file" do
        it "shows error and re-renders form" do
          with_batch_upload_v2_disabled do
            post certification_batch_uploads_path, params: { csv_file: nil }

            expect(response).to have_http_status(:unprocessable_content)
            expect(response.body).to include("Upload Certification Roster")
            expect(flash[:alert]).to eq("Please select a CSV file to upload")
          end
        end
      end
    end
  end

  describe "GET /staff/staff/certification_batch_uploads/:id" do
    let(:batch_upload) { create(:certification_batch_upload, uploader: user) }

    it "shows batch upload details" do
      get certification_batch_upload_path(batch_upload)

      expect(response).to be_successful
      expect(response.body).to include(batch_upload.filename)
    end
  end

  describe "POST /staff/staff/certification_batch_uploads/:id/process_batch" do
    include ActiveJob::TestHelper

    context "when batch is pending" do
      let(:batch_upload) { create(:certification_batch_upload, uploader: user, status: :pending) }

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
      let(:batch_upload) { create(:certification_batch_upload, uploader: user, status: :processing) }

      it "shows error and redirects" do
        post process_batch_certification_batch_upload_path(batch_upload)

        expect(response).to redirect_to(certification_batch_upload_path(batch_upload))
        expect(flash[:alert]).to include("cannot be processed")
      end
    end
  end

  describe "GET /staff/staff/certification_batch_uploads/:id/results" do
    let(:batch_upload) { create(:certification_batch_upload, :completed, uploader: user) }

    it "requires authentication" do
      logout
      get results_certification_batch_upload_path(batch_upload)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "requires admin authorization" do
      login_as create(:user, :as_caseworker)
      get results_certification_batch_upload_path(batch_upload)
      expect(response).to redirect_to("/staff")
    end

    context "with multiple certifications of different statuses" do
      let(:compliant_cert) { create(:certification) }
      let(:exempt_cert) { create(:certification) }
      let(:not_compliant_cert) { create(:certification) }
      let(:pending_review_cert) { create(:certification) }
      let(:awaiting_report_cert) { create(:certification) }

      let(:compliant_origin) do
        create(:certification_origin,
               certification_id: compliant_cert.id,
               source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
               source_id: batch_upload.id)
      end
      let(:exempt_origin) do
        create(:certification_origin,
               certification_id: exempt_cert.id,
               source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
               source_id: batch_upload.id)
      end
      let(:not_compliant_origin) do
        create(:certification_origin,
               certification_id: not_compliant_cert.id,
               source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
               source_id: batch_upload.id)
      end
      let(:pending_review_origin) do
        create(:certification_origin,
               certification_id: pending_review_cert.id,
               source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
               source_id: batch_upload.id)
      end
      let(:awaiting_report_origin) do
        create(:certification_origin,
               certification_id: awaiting_report_cert.id,
               source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
               source_id: batch_upload.id)
      end

      let(:compliant_determination) do
        create(:determination,
               subject_type: "Certification",
               subject_id: compliant_cert.id,
               outcome: MemberStatus::COMPLIANT,
               reasons: [ "hours_reported_compliant" ])
      end
      let(:exempt_determination) do
        create(:determination,
               subject_type: "Certification",
               subject_id: exempt_cert.id,
               outcome: MemberStatus::EXEMPT,
               reasons: [ "age_under_19_exempt" ])
      end
      let(:not_compliant_determination) do
        create(:determination,
               subject_type: "Certification",
               subject_id: not_compliant_cert.id,
               outcome: MemberStatus::NOT_COMPLIANT,
               reasons: [ "hours_reported_compliant" ])
      end

      # pending_review status comes from CertificationCase business process step
      let(:pending_review_case) do
        create(:certification_case,
               certification: pending_review_cert,
               business_process_current_step: CertificationBusinessProcess::REVIEW_ACTIVITY_REPORT_STEP)
      end

      # awaiting_report_cert has no determination and no case - will default to AWAITING_REPORT

      before do
        # Stub services to prevent auto-triggering during certification creation
        allow(Strata::EventManager).to receive(:publish).and_call_original
        allow(HoursComplianceDeterminationService).to receive(:determine)
        allow(ExemptionDeterminationService).to receive(:determine)
        allow(NotificationService).to receive(:send_email_notification)

        # Force creation of all test data
        compliant_origin
        exempt_origin
        not_compliant_origin
        pending_review_origin
        awaiting_report_origin
        compliant_determination
        exempt_determination
        not_compliant_determination
        pending_review_case
      end

      it "uses batch query (O(1)) to determine member statuses" do
        # Expected queries (11 total):
        # 1. Load batch upload
        # 2-5. ActiveStorage queries (attachments, blobs, variant_records)
        # 6. Load uploader user
        # 7. Load certification origins for batch
        # 8. Load certification cases
        # 9. Load strata tasks (for business process steps)
        # 10. Load certifications (batch hydration)
        # 11. Load determinations (batch query from MemberStatusService)
        # The key is that this is O(1) - constant regardless of # of certifications
        expect {
          get results_certification_batch_upload_path(batch_upload)
        }.not_to exceed_query_limit(11)
      end

      it "correctly displays filter counts" do
        get results_certification_batch_upload_path(batch_upload)

        expect(response).to be_successful
        # Verify filter buttons show correct counts
        expect(response.body).to include("All (5)")
        expect(response.body).to include("Compliant (1)")
        expect(response.body).to include("Exempt (1)")
        expect(response.body).to include("Member action required (2)")
        expect(response.body).to include("Pending review (1)")
      end

      it "correctly displays member statuses in the table" do
        get results_certification_batch_upload_path(batch_upload)

        expect(response).to be_successful
        expect(response.body).to include("Compliant")
        expect(response.body).to include("Exempt")
        expect(response.body).to include("Not compliant")
        expect(response.body).to include("Pending review")
        expect(response.body).to include("Awaiting report")
      end
    end
  end

  describe "GET /staff/staff/certification_batch_uploads" do
    context "when the user is a caseworker" do
      before do
        login_as create(:user, :as_caseworker)
      end

      it "renders a 403 response" do
        get certification_batch_uploads_path
        expect(response).to redirect_to("/staff")
      end
    end

    context "when the user is a member" do
      before do
        login_as create(:user)
      end

      it "renders a 403 response" do
        get certification_batch_uploads_path
        expect(response).to redirect_to("/dashboard")
      end
    end
  end
end
