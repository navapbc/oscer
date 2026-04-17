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
    allow(ExParteCommunityEngagementDeterminationService).to receive(:determine)
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(NotificationService).to receive(:send_email_notification)
  end

  describe "GET /staff/staff/certification_batch_uploads/new" do
    it "renders the direct upload form" do
      get new_certification_batch_upload_path

      expect(response).to be_successful
      expect(response.body).to include("Upload Certification Roster")
      expect(response.body).to include('data-direct-upload-url')
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
        expect(flash[:notice]).to include("Processing started")
      end

      it "attaches the file" do
        post certification_batch_uploads_path, params: { csv_file: uploaded_file }

        batch_upload = CertificationBatchUpload.last
        expect(batch_upload.file).to be_attached
        expect(batch_upload.filename).to include("test")
        expect(batch_upload.filename).to end_with(".csv")
      end

      it "creates batch upload with source_type ui" do
        post certification_batch_uploads_path, params: { csv_file: uploaded_file }

        batch_upload = CertificationBatchUpload.last
        expect(batch_upload.source_type).to eq("ui")
      end

      it "automatically enqueues processing job" do
        expect {
          post certification_batch_uploads_path, params: { csv_file: uploaded_file }
        }.to have_enqueued_job(ProcessCertificationBatchUploadJob)
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
    end

    context "without CSV file" do
      it "shows error and re-renders form" do
        post certification_batch_uploads_path, params: { csv_file: nil }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Upload Certification Roster")
        expect(flash[:alert]).to eq("Please select a CSV file to upload")
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

    context "with completed upload and no errors" do
      let(:batch_upload) do
        create(:certification_batch_upload, :completed,
               uploader: user, num_rows_succeeded: 10, num_rows_errored: 0, num_rows: 10)
      end

      it "shows success summary" do
        get certification_batch_upload_path(batch_upload)

        expect(response).to be_successful
        expect(response.body).to include("All 10 records processed successfully")
        expect(response.body).not_to include("error-table")
      end
    end

    context "with completed upload and errors" do
      let(:batch_upload) do
        create(:certification_batch_upload, :completed,
               uploader: user, num_rows_succeeded: 8, num_rows_errored: 2, num_rows: 10)
      end

      it "shows error table from upload_errors association" do
        create(
          :certification_batch_upload_error,
          certification_batch_upload: batch_upload,
          row_number: 2,
          error_code: "VAL_001",
          error_message: "Missing required field",
          row_data: { "member_id" => "M001" }
        )
        create(
          :certification_batch_upload_error,
          certification_batch_upload: batch_upload,
          row_number: 5,
          error_code: "VAL_002",
          error_message: "Invalid date format",
          row_data: { "member_id" => "M002" }
        )

        get certification_batch_upload_path(batch_upload)

        expect(response).to be_successful
        expect(response.body).to include("error-table")
        expect(response.body).to include("VAL_001")
        expect(response.body).to include("Missing required field")
        expect(response.body).to include("VAL_002")
        expect(response.body).to include("Invalid date format")
        expect(response.body).to include("Download Errors CSV")
      end
    end

    context "with completed upload and more than 100 errors" do
      let(:batch_upload) do
        create(:certification_batch_upload, :completed,
               uploader: user, num_rows_succeeded: 0, num_rows_errored: 150, num_rows: 150)
      end

      it "shows truncation message" do
        create_list(:certification_batch_upload_error, 101, certification_batch_upload: batch_upload)

        get certification_batch_upload_path(batch_upload)

        expect(response).to be_successful
        expect(response.body).to include("Showing first 100 of 150 errors")
      end
    end

    context "with failed upload (no regression)" do
      let(:batch_upload) do
        create(:certification_batch_upload, :failed, uploader: user,
               results: { "error" => "CSV parsing failed: invalid encoding" })
      end

      it "renders error message from results" do
        get certification_batch_upload_path(batch_upload)

        expect(response).to be_successful
        expect(response.body).to include("CSV parsing failed: invalid encoding")
      end
    end

    context "with processing upload" do
      let(:batch_upload) { create(:certification_batch_upload, :processing, uploader: user) }

      it "shows processing progress message" do
        get certification_batch_upload_path(batch_upload)

        expect(response).to be_successful
        expect(response.body).to include("5", "10")
      end
    end

    context "with pending upload" do
      let(:batch_upload) { create(:certification_batch_upload, uploader: user, status: :pending) }

      it "shows queued message and hides Process button" do
        get certification_batch_upload_path(batch_upload)

        expect(response).to be_successful
        expect(response.body).to include("queued for processing")
        expect(response.body).not_to include("Process This File")
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
        allow(ExParteCommunityEngagementDeterminationService).to receive(:determine)
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

  describe "GET /staff/staff/certification_batch_uploads (dashboard)" do
    describe "auto-refresh behavior" do
      it "renders auto-refresh active when processing uploads exist" do
        create(:certification_batch_upload, :processing, uploader: user)

        get certification_batch_uploads_path

        expect(response).to be_successful
        expect(response.body).to include('data-auto-refresh-active-value="true"')
      end

      it "renders auto-refresh inactive when only completed uploads exist" do
        create(:certification_batch_upload, :completed, uploader: user)

        get certification_batch_uploads_path

        expect(response).to be_successful
        expect(response.body).to include('data-auto-refresh-active-value="false"')
      end

      it "responds to Turbo Frame requests" do
        create(:certification_batch_upload, uploader: user)

        get certification_batch_uploads_path, headers: { "Turbo-Frame" => "uploads_table" }

        expect(response).to be_successful
        expect(response.body).to include("uploads_table")
      end
    end

    describe "error display" do
      let(:batch_upload) { create(:certification_batch_upload, :completed, uploader: user) }

      it "shows error count for completed upload with errors" do
        create(:certification_batch_upload_error, certification_batch_upload: batch_upload, row_number: 1)
        create(:certification_batch_upload_error, certification_batch_upload: batch_upload, row_number: 2)

        get certification_batch_uploads_path

        expect(response).to be_successful
        expect(response.body).to include("2 errors")
      end

      it "shows download errors link for completed upload with errors" do
        create(:certification_batch_upload_error, certification_batch_upload: batch_upload, row_number: 1)

        get certification_batch_uploads_path

        expect(response).to be_successful
        expect(response.body).to include("Download Errors")
      end

      it "shows 'No errors' for completed upload without errors" do
        create(:certification_batch_upload, :completed, uploader: user, num_rows_errored: 0)

        get certification_batch_uploads_path

        expect(response).to be_successful
        expect(response.body).to include("No errors")
        expect(response.body).not_to include("Download Errors")
      end
    end

    context "with pending upload" do
      it "shows Queued text instead of Process button" do
        create(:certification_batch_upload, uploader: user, status: :pending)

        get certification_batch_uploads_path

        expect(response).to be_successful
        expect(response.body).to include("Queued")
        expect(response.body).not_to include('value="Process"')
      end
    end
  end

  describe "GET /staff/staff/certification_batch_uploads/:id/download_errors" do
    let(:batch_upload) { create(:certification_batch_upload, :completed, uploader: user) }

    it "returns CSV with correct headers and data" do
      create(
        :certification_batch_upload_error,
        certification_batch_upload: batch_upload,
        row_number: 2,
        error_code: "VAL_001",
        error_message: "Missing required field",
        row_data: { "member_id" => "M001", "case_number" => "C-001" }
      )

      get download_errors_certification_batch_upload_path(batch_upload)

      expect(response).to be_successful
      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("errors.csv")
      expect(response.body).to include("Row,Error Code,Error Message,Row Data")
      expect(response.body).to include("2,VAL_001,Missing required field,")
    end

    it "orders errors by row_number" do
      create(:certification_batch_upload_error, certification_batch_upload: batch_upload, row_number: 5, error_message: "Error five")
      create(:certification_batch_upload_error, certification_batch_upload: batch_upload, row_number: 2, error_message: "Error two")
      create(:certification_batch_upload_error, certification_batch_upload: batch_upload, row_number: 10, error_message: "Error ten")

      get download_errors_certification_batch_upload_path(batch_upload)

      lines = response.body.strip.split("\n")
      data_lines = lines[1..]
      row_numbers = data_lines.map { |line| line.split(",").first.to_i }
      expect(row_numbers).to eq([ 2, 5, 10 ])
    end

    it "returns header-only CSV when no errors exist" do
      get download_errors_certification_batch_upload_path(batch_upload)

      expect(response).to be_successful
      expect(response.body.strip).to eq("Row,Error Code,Error Message,Row Data")
    end

    context "when the user is a caseworker" do
      before do
        login_as create(:user, :as_caseworker)
      end

      it "redirects (unauthorized)" do
        get download_errors_certification_batch_upload_path(batch_upload)
        expect(response).to redirect_to("/staff")
      end
    end

    context "when the user is a member" do
      before do
        login_as create(:user)
      end

      it "redirects (unauthorized)" do
        get download_errors_certification_batch_upload_path(batch_upload)
        expect(response).to redirect_to("/dashboard")
      end
    end
  end

  describe "authorization" do
    context "when the user is a caseworker" do
      before do
        login_as create(:user, :as_caseworker)
      end

      it "redirects from index" do
        get certification_batch_uploads_path
        expect(response).to redirect_to("/staff")
      end
    end

    context "when the user is a member" do
      before do
        login_as create(:user)
      end

      it "redirects from index" do
        get certification_batch_uploads_path
        expect(response).to redirect_to("/dashboard")
      end
    end
  end
end
