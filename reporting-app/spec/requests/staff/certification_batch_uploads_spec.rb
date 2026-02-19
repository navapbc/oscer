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

    context "with batch_upload_v2 feature flag enabled" do
      it "renders the direct upload form" do
        with_batch_upload_v2_enabled do
          get new_certification_batch_upload_path

          expect(response).to be_successful
          expect(response.body).to include("Upload Certification Roster")
          expect(response.body).to include('data-direct-upload-url')
        end
      end
    end

    context "with batch_upload_v2 feature flag disabled" do
      it "renders the legacy upload form" do
        with_batch_upload_v2_disabled do
          get new_certification_batch_upload_path

          expect(response).to be_successful
          expect(response.body).to include("Upload Certification Roster")
          expect(response.body).not_to include('data-direct-upload-url')
        end
      end
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

      context "with batch_upload_v2 feature flag enabled" do
        it "creates batch upload with source_type ui" do
          with_batch_upload_v2_enabled do
            post certification_batch_uploads_path, params: { csv_file: uploaded_file }

            batch_upload = CertificationBatchUpload.last
            expect(batch_upload.source_type).to eq("ui")
          end
        end

        it "attaches the file via direct upload" do
          with_batch_upload_v2_enabled do
            post certification_batch_uploads_path, params: { csv_file: uploaded_file }

            batch_upload = CertificationBatchUpload.last
            expect(batch_upload.file).to be_attached
            expect(batch_upload.filename).to include("test")
          end
        end

        it "automatically enqueues processing job" do
          with_batch_upload_v2_enabled do
            expect {
              post certification_batch_uploads_path, params: { csv_file: uploaded_file }
            }.to have_enqueued_job(ProcessCertificationBatchUploadJob)
          end
        end

        it "redirects to show page (not index)" do
          with_batch_upload_v2_enabled do
            post certification_batch_uploads_path, params: { csv_file: uploaded_file }

            batch_upload = CertificationBatchUpload.last
            expect(response).to redirect_to(certification_batch_upload_path(batch_upload))
          end
        end

        it "displays processing started message" do
          with_batch_upload_v2_enabled do
            post certification_batch_uploads_path, params: { csv_file: uploaded_file }

            follow_redirect!
            expect(response.body).to include("Processing started")
          end
        end
      end

      context "with malicious filename" do
        let(:malicious_file) do
          # Create temp file
          file = Tempfile.new([ "test", ".csv" ])
          file.write("member_id,case_number\n123,ABC")
          file.rewind
          # Set malicious original_filename
          Rack::Test::UploadedFile.new(
            file.path,
            "text/csv",
            original_filename: "../../etc/passwd<script>alert('xss')</script>.csv"
          )
        end

        it "sanitizes filename to prevent path traversal and XSS" do
          post certification_batch_uploads_path, params: { csv_file: malicious_file }

          batch_upload = CertificationBatchUpload.last
          # Should remove path components and replace special characters with underscores
          expect(batch_upload.filename).not_to include("..")
          expect(batch_upload.filename).not_to include("/")
          expect(batch_upload.filename).not_to include("<")
          expect(batch_upload.filename).not_to include(">")
          expect(batch_upload.filename).not_to include("(")
          expect(batch_upload.filename).not_to include(")")
          expect(batch_upload.filename).not_to include("'")
          # Should end with .csv and only contain safe characters (alphanumeric, dash, underscore, period)
          expect(batch_upload.filename).to match(/\A[\w\-\.]+\.csv\z/)
        end
      end

      context "with batch_upload_v2 feature flag disabled" do
        it "creates batch upload with source_type ui" do
          with_batch_upload_v2_disabled do
            post certification_batch_uploads_path, params: { csv_file: uploaded_file }

            batch_upload = CertificationBatchUpload.last
            expect(batch_upload.source_type).to eq("ui")
          end
        end

        it "attaches the file via legacy multipart upload" do
          with_batch_upload_v2_disabled do
            post certification_batch_uploads_path, params: { csv_file: uploaded_file }

            batch_upload = CertificationBatchUpload.last
            expect(batch_upload.file).to be_attached
          end
        end
      end
    end

    context "without CSV file" do
      it "shows error and re-renders form" do
        post certification_batch_uploads_path, params: { csv_file: nil }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Upload Certification Roster")
        expect(flash[:alert]).to eq("Please select a CSV file to upload")
      end

      context "with batch_upload_v2 feature flag enabled" do
        it "shows error and re-renders form" do
          with_batch_upload_v2_enabled do
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
