# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Staff::CertificationBatchUploadsController, type: :controller do
  let(:user) { create(:user, :as_admin) }

  before do
    sign_in user
  end

  describe "POST #create" do
    let(:csv_file) { fixture_file_upload('spec/fixtures/files/certification_batch_upload_test_file.csv', 'text/csv') }

    context "when a valid CSV file is uploaded" do
      it "creates a new CertificationBatchUpload" do
        expect {
          post :create, params: { csv_file: csv_file, locale: "en" }
        }.to change(CertificationBatchUpload, :count).from(0).to(1)
      end

      it "sets the filename from the uploaded file" do
        post :create, params: { csv_file: csv_file, locale: "en" }

        batch_upload = CertificationBatchUpload.last

        expect(batch_upload.filename).to eq(csv_file.original_filename)
      end

      it "sets the uploader to the current user" do
        post :create, params: { csv_file: csv_file, locale: "en" }

        batch_upload = CertificationBatchUpload.includes(:uploader).last

        expect(batch_upload.uploader).to eq(user)
      end

      it "attaches the uploaded file" do
        post :create, params: { csv_file: csv_file, locale: "en" }

        batch_upload = CertificationBatchUpload.last

        expect(batch_upload.file).to be_attached
      end

      it "redirects to certification_batch_uploads_path" do
        post :create, params: { csv_file: csv_file, locale: "en" }

        expect(response).to redirect_to(certification_batch_uploads_path)
      end

      it "sets a success notice" do
        post :create, params: { csv_file: csv_file, locale: "en" }

        expect(flash[:notice]).to eq("Processing started for certification_batch_upload_test_file.csv. Results will be available shortly.")
      end

      it "enqueues processing job" do
        allow(ProcessCertificationBatchUploadJob).to receive(:perform_later)

        post :create, params: { csv_file: csv_file, locale: "en" }

        expect(ProcessCertificationBatchUploadJob).to have_received(:perform_later)
      end
    end

    context "when a signed blob ID is submitted (direct upload)" do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: File.open(Rails.root.join("spec/fixtures/files/certification_batch_upload_test_file.csv")),
          filename: "direct_upload_test.csv",
          content_type: "text/csv"
        )
      end

      it "creates a new CertificationBatchUpload" do
        expect {
          post :create, params: { csv_file: blob.signed_id, locale: "en" }
        }.to change(CertificationBatchUpload, :count).by(1)
      end

      it "sets the filename from the blob" do
        post :create, params: { csv_file: blob.signed_id, locale: "en" }

        batch_upload = CertificationBatchUpload.last
        expect(batch_upload.filename).to eq("direct_upload_test.csv")
      end

      it "attaches the file from the blob" do
        post :create, params: { csv_file: blob.signed_id, locale: "en" }

        batch_upload = CertificationBatchUpload.last
        expect(batch_upload.file).to be_attached
      end

      it "enqueues processing job automatically" do
        allow(ProcessCertificationBatchUploadJob).to receive(:perform_later)

        post :create, params: { csv_file: blob.signed_id, locale: "en" }

        expect(ProcessCertificationBatchUploadJob).to have_received(:perform_later)
      end

      it "handles invalid signed blob IDs gracefully" do
        post :create, params: { csv_file: "invalid-signed-id", locale: "en" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash.now[:alert]).to eq("Upload failed. Please try again.")
      end
    end

    context "when no file is uploaded" do
      it "does not create a CertificationBatchUpload" do
        expect {
          post :create, params: { locale: "en" }
        }.not_to change(CertificationBatchUpload, :count)
      end

      it "sets an alert message" do
        post :create, params: { locale: "en" }

        expect(flash.now[:alert]).to eq("Please select a CSV file to upload")
      end

      it "returns unprocessable_content status" do
        post :create, params: { locale: "en" }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "assigns a new batch_upload instance" do
        post :create, params: { locale: "en" }

        expect(controller.instance_variable_get(:@batch_upload)).to be_a_new(CertificationBatchUpload)
      end
    end

    context "when batch upload fails to save" do
      let(:certification_batch_upload) { instance_double(CertificationBatchUpload) }
      let(:file_attachment) { instance_double(ActiveStorage::Attached::One) }
      let(:errors_double) { instance_double(ActiveModel::Errors, full_messages: [ "Filename can't be blank", "File must be attached" ]) }

      before do
        allow(CertificationBatchUpload).to receive(:new).and_return(certification_batch_upload)
        allow(file_attachment).to receive(:attach)
        allow(certification_batch_upload).to receive_messages(file: file_attachment, save: false, errors: errors_double)
      end

      it "does not create a CertificationBatchUpload" do
        expect {
          post :create, params: { csv_file: csv_file, locale: "en" }
        }.not_to change(CertificationBatchUpload, :count)
      end

      it "redirects to new_certification_batch_upload_path" do
        post :create, params: { csv_file: csv_file, locale: "en" }

        expect(response).to redirect_to(new_certification_batch_upload_path)
      end

      it "sets an error alert with validation messages" do
        post :create, params: { csv_file: csv_file, locale: "en" }

        expect(flash[:alert]).to eq("Failed to upload file: Filename can't be blank, File must be attached")
      end

      it "returns unprocessable_content status for JSON requests" do
        post :create, params: { csv_file: csv_file, locale: "en", format: :json }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns error message in JSON for JSON requests" do
        post :create, params: { csv_file: csv_file, locale: "en", format: :json }

        expect(JSON.parse(response.body)).to eq({ "error" => "Failed to upload file: Filename can't be blank, File must be attached" })
      end
    end
  end

  describe "GET #results" do
    let(:batch_upload) { create(:certification_batch_upload) }

    context "with empty batch upload" do
      it "renders" do
        get :results, params: { id: batch_upload.id, locale: "en" }
        expect(response).to have_http_status(:ok)
      end
    end

    context "with certification cases of various statuses" do
      let(:compliant_cert) { create(:certification) }
      let(:exempt_cert) { create(:certification) }
      let(:not_compliant_cert) { create(:certification) }
      let(:pending_review_cert) { create(:certification) }

      let(:compliant_case) { create(:certification_case, certification: compliant_cert) }
      let(:exempt_case) { create(:certification_case, certification: exempt_cert) }
      let(:not_compliant_case) { create(:certification_case, certification: not_compliant_cert) }
      let(:pending_review_case) { create(:certification_case, certification: pending_review_cert) }

      # Default status for pending_review_cert (can be overridden in specific contexts)
      let(:pending_review_cert_status) { MemberStatus::PENDING_REVIEW }

      before do
        # Create cases (which will create certifications as dependencies)
        compliant_case
        exempt_case
        not_compliant_case
        pending_review_case

        # Create certification origins linking certifications to batch upload
        CertificationOrigin.create!(
          certification_id: compliant_cert.id,
          source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
          source_id: batch_upload.id
        )
        CertificationOrigin.create!(
          certification_id: exempt_cert.id,
          source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
          source_id: batch_upload.id
        )
        CertificationOrigin.create!(
          certification_id: not_compliant_cert.id,
          source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
          source_id: batch_upload.id
        )
        CertificationOrigin.create!(
          certification_id: pending_review_cert.id,
          source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
          source_id: batch_upload.id
        )

        # Stub MemberStatusService.determine_many to return statuses keyed by [class_name, id]
        allow(MemberStatusService).to receive(:determine_many).and_return(
          {
            [ "CertificationCase", compliant_case.id ] => MemberStatus.new(status: MemberStatus::COMPLIANT, determination_method: "automated", reason_codes: []),
            [ "CertificationCase", exempt_case.id ] => MemberStatus.new(status: MemberStatus::EXEMPT, determination_method: "automated", reason_codes: [ "age_under_19_exempt" ]),
            [ "CertificationCase", not_compliant_case.id ] => MemberStatus.new(status: MemberStatus::NOT_COMPLIANT, determination_method: "automated", reason_codes: []),
            [ "CertificationCase", pending_review_case.id ] => MemberStatus.new(status: pending_review_cert_status, determination_method: "manual", reason_codes: [])
          }
        )
      end

      context "when accessing without filters" do
        it "loads certification cases from the batch upload" do
          get :results, params: { id: batch_upload.id, locale: "en" }

          cases = controller.instance_variable_get(:@certification_cases)
          expect(cases).to contain_exactly(compliant_case, exempt_case, not_compliant_case, pending_review_case)
        end

        it "calculates member statuses for all certification cases" do
          get :results, params: { id: batch_upload.id, locale: "en" }

          expect(controller.instance_variable_get(:@member_statuses)).to be_present
          expect(controller.instance_variable_get(:@member_statuses)[[ "CertificationCase", compliant_case.id ]].status).to eq(MemberStatus::COMPLIANT)
          expect(controller.instance_variable_get(:@member_statuses)[[ "CertificationCase", exempt_case.id ]].status).to eq(MemberStatus::EXEMPT)
          expect(controller.instance_variable_get(:@member_statuses)[[ "CertificationCase", not_compliant_case.id ]].status).to eq(MemberStatus::NOT_COMPLIANT)
          expect(controller.instance_variable_get(:@member_statuses)[[ "CertificationCase", pending_review_case.id ]].status).to eq(MemberStatus::PENDING_REVIEW)
        end

        it "groups certification cases by status" do
          get :results, params: { id: batch_upload.id, locale: "en" }

          expect(controller.instance_variable_get(:@compliant_cases)).to contain_exactly(compliant_case)
          expect(controller.instance_variable_get(:@exempt_cases)).to contain_exactly(exempt_case)
          expect(controller.instance_variable_get(:@member_action_required_cases)).to contain_exactly(not_compliant_case)
          expect(controller.instance_variable_get(:@pending_review_cases)).to contain_exactly(pending_review_case)
        end

        it "shows all certification cases by default" do
          get :results, params: { id: batch_upload.id, locale: "en" }

          expect(controller.instance_variable_get(:@cases_to_show)).to contain_exactly(compliant_case, exempt_case, not_compliant_case, pending_review_case)
        end

        it "renders successfully" do
          get :results, params: { id: batch_upload.id, locale: "en" }

          expect(response).to have_http_status(:success)
        end
      end

      context "when filtering by compliant" do
        it "shows only compliant certification cases" do
          get :results, params: { id: batch_upload.id, filter: "compliant", locale: "en" }

          expect(controller.instance_variable_get(:@cases_to_show)).to contain_exactly(compliant_case)
        end
      end

      context "when filtering by exempt" do
        it "shows only exempt certification cases" do
          get :results, params: { id: batch_upload.id, filter: "exempt", locale: "en" }

          expect(controller.instance_variable_get(:@cases_to_show)).to contain_exactly(exempt_case)
        end
      end

      context "when filtering by member_action_required" do
        # Override to use AWAITING_REPORT status for this test
        let(:pending_review_cert_status) { MemberStatus::AWAITING_REPORT }

        it "shows certification cases requiring member action" do
          get :results, params: { id: batch_upload.id, filter: "member_action_required", locale: "en" }

          expect(controller.instance_variable_get(:@cases_to_show)).to contain_exactly(not_compliant_case, pending_review_case)
        end
      end

      context "when filtering by pending_review" do
        it "shows only pending review certification cases" do
          get :results, params: { id: batch_upload.id, filter: "pending_review", locale: "en" }

          expect(controller.instance_variable_get(:@cases_to_show)).to contain_exactly(pending_review_case)
        end
      end
    end
  end
end
