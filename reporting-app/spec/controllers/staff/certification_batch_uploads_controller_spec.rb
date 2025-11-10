# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Staff::CertificationBatchUploadsController, type: :controller do
  let(:user) { create(:user) }

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

        expect(flash[:notice]).to eq("File uploaded successfully. You can now process it from the queue.")
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

      it "renders the new template" do
        post :create, params: { locale: "en" }

        expect(response).to render_template(:new)
      end

      it "returns unprocessable_content status" do
        post :create, params: { locale: "en" }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "assigns a new batch_upload instance" do
        post :create, params: { locale: "en" }

        expect(assigns(:batch_upload)).to be_a_new(CertificationBatchUpload)
      end
    end

    context "when batch upload fails to save" do
      let(:certification_batch_upload) { instance_double(CertificationBatchUpload) }
      let(:file_attachment) { double("file_attachment") }

      before do
        allow(CertificationBatchUpload).to receive(:new).and_return(certification_batch_upload)
        allow(certification_batch_upload).to receive(:file).and_return(file_attachment)
        allow(file_attachment).to receive(:attach)
        allow(certification_batch_upload).to receive(:save).and_return(false)
        allow(certification_batch_upload).to receive(:errors).and_return(
          double(full_messages: [ "Filename can't be blank", "File must be attached" ])
        )
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

      context "when requesting JSON format" do
        it "returns unprocessable_entity status" do
          post :create, params: { csv_file: csv_file, locale: "en", format: :json }

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns error message in JSON" do
          post :create, params: { csv_file: csv_file, locale: "en", format: :json }

          expect(JSON.parse(response.body)).to eq({ "error" => "Failed to upload file: Filename can't be blank, File must be attached" })
        end
      end
    end
  end

  describe "GET #results" do
    let(:batch_upload) { create(:certification_batch_upload) }
    let(:compliant_cert) { create(:certification) }
    let(:exempt_cert) { create(:certification) }
    let(:not_compliant_cert) { create(:certification) }
    let(:pending_review_cert) { create(:certification) }

    # Default status for pending_review_cert (can be overridden in specific contexts)
    let(:pending_review_cert_status) { MemberStatus::PENDING_REVIEW }

    before do
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

      # Stub MemberStatusService to return different statuses
      allow(MemberStatusService).to receive(:determine).with(compliant_cert).and_return(
        MemberStatus.new(status: MemberStatus::COMPLIANT, determination_method: "automated", reason_codes: [])
      )
      allow(MemberStatusService).to receive(:determine).with(exempt_cert).and_return(
        MemberStatus.new(status: MemberStatus::EXEMPT, determination_method: "automated", reason_codes: [ "age_under_19_exempt" ])
      )
      allow(MemberStatusService).to receive(:determine).with(not_compliant_cert).and_return(
        MemberStatus.new(status: MemberStatus::NOT_COMPLIANT, determination_method: "automated", reason_codes: [])
      )
      allow(MemberStatusService).to receive(:determine).with(pending_review_cert).and_return(
        MemberStatus.new(status: pending_review_cert_status, determination_method: "manual", reason_codes: [])
      )
    end

    context "when accessing without filters" do
      it "loads certifications from the batch upload" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        certifications = controller.instance_variable_get(:@certifications)
        expect(certifications).to contain_exactly(compliant_cert, exempt_cert, not_compliant_cert, pending_review_cert)
      end

      it "calculates member statuses for all certifications" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        expect(assigns(:member_statuses)).to be_present
        expect(assigns(:member_statuses)[compliant_cert.id].status).to eq(MemberStatus::COMPLIANT)
        expect(assigns(:member_statuses)[exempt_cert.id].status).to eq(MemberStatus::EXEMPT)
        expect(assigns(:member_statuses)[not_compliant_cert.id].status).to eq(MemberStatus::NOT_COMPLIANT)
        expect(assigns(:member_statuses)[pending_review_cert.id].status).to eq(MemberStatus::PENDING_REVIEW)
      end

      it "groups certifications by status" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        expect(assigns(:compliant_certifications)).to contain_exactly(compliant_cert)
        expect(assigns(:exempt_certifications)).to contain_exactly(exempt_cert)
        expect(assigns(:member_action_required_certifications)).to contain_exactly(not_compliant_cert)
        expect(assigns(:pending_review_certifications)).to contain_exactly(pending_review_cert)
      end

      it "shows all certifications by default" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        expect(assigns(:certifications_to_show)).to contain_exactly(compliant_cert, exempt_cert, not_compliant_cert, pending_review_cert)
      end

      it "renders successfully" do
        get :results, params: { id: batch_upload.id, locale: "en" }

        expect(response).to have_http_status(:success)
      end
    end

    context "when filtering by compliant" do
      it "shows only compliant certifications" do
        get :results, params: { id: batch_upload.id, filter: "compliant", locale: "en" }

        expect(assigns(:certifications_to_show)).to contain_exactly(compliant_cert)
      end
    end

    context "when filtering by exempt" do
      it "shows only exempt certifications" do
        get :results, params: { id: batch_upload.id, filter: "exempt", locale: "en" }

        expect(assigns(:certifications_to_show)).to contain_exactly(exempt_cert)
      end
    end

    context "when filtering by member_action_required" do
      # Override to use AWAITING_REPORT status for this test
      let(:pending_review_cert_status) { MemberStatus::AWAITING_REPORT }

      it "shows certifications requiring member action" do
        get :results, params: { id: batch_upload.id, filter: "member_action_required", locale: "en" }

        expect(assigns(:certifications_to_show)).to contain_exactly(not_compliant_cert, pending_review_cert)
      end
    end

    context "when filtering by pending_review" do
      it "shows only pending review certifications" do
        get :results, params: { id: batch_upload.id, filter: "pending_review", locale: "en" }

        expect(assigns(:certifications_to_show)).to contain_exactly(pending_review_cert)
      end
    end
  end

  describe "POST #process_batch" do
    let(:batch_upload) { create(:certification_batch_upload, status: batch_status) }
    
    context "when batch upload is processable" do
      let(:batch_upload_job) { instance_double(ProcessCertificationBatchUploadJob) }
      let(:batch_status) { "pending" }

      context "when job is enqueued successfully" do
        before do
          allow(ProcessCertificationBatchUploadJob).to receive(:perform_later).and_return(batch_upload_job)
        end

        it "enqueues ProcessCertificationBatchUploadJob" do
          post :process_batch, params: { id: batch_upload.id, locale: "en" }

          expect(ProcessCertificationBatchUploadJob).to have_received(:perform_later).with(batch_upload.id)
        end

        it "redirects to certification_batch_uploads_path" do
          post :process_batch, params: { id: batch_upload.id, locale: "en" }

          expect(response).to redirect_to(certification_batch_uploads_path)
        end

        it "sets a success notice" do
          post :process_batch, params: { id: batch_upload.id, locale: "en" }

          expect(flash[:notice]).to eq("Processing started for #{batch_upload.filename}. Results will be available shortly.")
        end

        context "when requesting JSON format" do
          it "returns accepted status" do
            post :process_batch, params: { id: batch_upload.id, locale: "en", format: :json }

            expect(response).to have_http_status(:accepted)
          end
        end
      end

      context "when job fails to enqueue" do
        before do
          allow(ProcessCertificationBatchUploadJob).to receive(:perform_later).and_return(false)
        end

        it "redirects back to the batch upload page" do
          post :process_batch, params: { id: batch_upload.id, locale: "en" }

          expect(response).to redirect_to(certification_batch_upload_path(batch_upload))
        end

        it "sets an error alert" do
          post :process_batch, params: { id: batch_upload.id, locale: "en" }

          expect(flash[:alert]).to eq("Failed to start processing job.")
        end

        context "when requesting JSON format" do
          it "returns internal server error status" do
            post :process_batch, params: { id: batch_upload.id, locale: "en", format: :json }

            expect(response).to have_http_status(:internal_server_error)
          end

          it "returns error message in JSON" do
            post :process_batch, params: { id: batch_upload.id, locale: "en", format: :json }

            expect(JSON.parse(response.body)).to eq({ "error" => "Failed to start processing job." })
          end
        end
      end
    end

    context "when batch upload is not processable" do
      let(:batch_status) { "processing" }

      before do
        allow(ProcessCertificationBatchUploadJob).to receive(:perform_later).and_return(false)
      end

      it "does not enqueue ProcessCertificationBatchUploadJob" do
        post :process_batch, params: { id: batch_upload.id, locale: "en" }

        expect(ProcessCertificationBatchUploadJob).not_to have_received(:perform_later)
      end

      it "redirects back to the batch upload page" do
        post :process_batch, params: { id: batch_upload.id, locale: "en" }

        expect(response).to redirect_to(certification_batch_upload_path(batch_upload))
      end

      it "sets an error alert with current status" do
        post :process_batch, params: { id: batch_upload.id, locale: "en" }

        expect(flash[:alert]).to eq("This batch cannot be processed. Current status: #{batch_status}.")
      end

      context "when requesting JSON format" do
        it "returns unprocessable entity status" do
          post :process_batch, params: { id: batch_upload.id, locale: "en", format: :json }

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns error message in JSON" do
          post :process_batch, params: { id: batch_upload.id, locale: "en", format: :json }

          expect(JSON.parse(response.body)).to eq({ "error" => "This batch cannot be processed. Current status: #{batch_status}." })
        end
      end

      context "when batch status is completed" do
        let(:batch_status) { "completed" }

        it "prevents reprocessing" do
          post :process_batch, params: { id: batch_upload.id, locale: "en" }

          expect(ProcessCertificationBatchUploadJob).not_to have_received(:perform_later)
          expect(flash[:alert]).to include("Current status: completed")
        end
      end

      context "when batch status is failed" do
        let(:batch_status) { "failed" }

        it "prevents reprocessing" do
          post :process_batch, params: { id: batch_upload.id, locale: "en" }
          
          expect(ProcessCertificationBatchUploadJob).not_to have_received(:perform_later)
          expect(flash[:alert]).to include("Current status: failed")
        end
      end
    end
  end
end
