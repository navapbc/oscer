# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/api/certification_batch_uploads", type: :request do
  def auth_headers(params = nil)
    body = params ? params.to_json : ""
    hmac_auth_headers(body: body, secret: Rails.configuration.api_secret_key)
  end

  def create_blob(filename: "test_upload.csv", content: "member_id,case_number\nM001,C-001")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: filename,
      content_type: "text/csv"
    )
  end

  describe "POST /api/certification_batch_uploads" do
    context "when batch_upload_v2 flag is disabled" do
      it "returns 404" do
        with_batch_upload_v2_disabled do
          params = { signed_blob_id: "anything" }
          post api_certification_batch_uploads_url,
               params: params,
               headers: auth_headers(params),
               as: :json

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when batch_upload_v2 flag is enabled" do
      it "returns 401 without HMAC auth" do
        with_batch_upload_v2_enabled do
          post api_certification_batch_uploads_url,
               params: { signed_blob_id: "anything" },
               as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end

      it "creates a batch upload and enqueues processing job" do
        with_batch_upload_v2_enabled do
          blob = create_blob
          params = { signed_blob_id: blob.signed_id }

          expect {
            post api_certification_batch_uploads_url,
                 params: params,
                 headers: auth_headers(params),
                 as: :json
          }.to change(CertificationBatchUpload, :count).by(1)

          expect(response).to have_http_status(:created)

          body = response.parsed_body
          expect(body["id"]).to be_present
          expect(body["status"]).to eq("pending")
          expect(body["filename"]).to eq("test_upload.csv")
          expect(body["source_type"]).to eq("api")

          batch_upload = CertificationBatchUpload.find(body["id"])
          expect(batch_upload.uploader).to be_nil
          expect(batch_upload.source_type).to eq("api")
          expect(batch_upload.file).to be_attached

          expect(ProcessCertificationBatchUploadJob).to have_been_enqueued.with(batch_upload.id)
        end
      end

      it "returns 422 for invalid signed blob ID" do
        with_batch_upload_v2_enabled do
          params = { signed_blob_id: "invalid-blob-id" }
          post api_certification_batch_uploads_url,
               params: params,
               headers: auth_headers(params),
               as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      it "returns 422 when signed_blob_id is missing" do
        with_batch_upload_v2_enabled do
          params = {}
          post api_certification_batch_uploads_url,
               params: params,
               headers: auth_headers(params),
               as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      it "sanitizes the filename" do
        with_batch_upload_v2_enabled do
          blob = create_blob(filename: "../../../etc/passwd.csv")
          params = { signed_blob_id: blob.signed_id }

          post api_certification_batch_uploads_url,
               params: params,
               headers: auth_headers(params),
               as: :json

          expect(response).to have_http_status(:created)
          batch_upload = CertificationBatchUpload.last
          # ActiveStorage::Filename replaces path separators with dashes on creation,
          # then our sanitizer replaces non-word chars with underscores
          expect(batch_upload.filename).not_to include("/")
          expect(batch_upload.filename).to match(/\A[\w\-.]+\z/)
        end
      end
    end
  end

  describe "GET /api/certification_batch_uploads/:id" do
    context "when batch_upload_v2 flag is disabled" do
      it "returns 404" do
        with_batch_upload_v2_disabled do
          batch_upload = create(:certification_batch_upload, :api_sourced)
          get api_certification_batch_upload_url(batch_upload),
              headers: auth_headers

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when batch_upload_v2 flag is enabled" do
      it "returns 401 without HMAC auth" do
        with_batch_upload_v2_enabled do
          batch_upload = create(:certification_batch_upload, :api_sourced)
          get api_certification_batch_upload_url(batch_upload)

          expect(response).to have_http_status(:unauthorized)
        end
      end

      it "returns status for an API-sourced batch upload" do
        with_batch_upload_v2_enabled do
          batch_upload = create(:certification_batch_upload, :api_sourced, :completed)

          get api_certification_batch_upload_url(batch_upload),
              headers: auth_headers

          expect(response).to have_http_status(:ok)

          body = response.parsed_body
          expect(body["id"]).to eq(batch_upload.id)
          expect(body["status"]).to eq("completed")
          expect(body["filename"]).to eq(batch_upload.filename)
          expect(body["source_type"]).to eq("api")
          expect(body["num_rows"]).to eq(10)
          expect(body["num_rows_processed"]).to eq(10)
          expect(body["num_rows_succeeded"]).to eq(8)
          expect(body["num_rows_errored"]).to eq(2)
        end
      end

      it "cannot view staff-sourced batch uploads" do
        with_batch_upload_v2_enabled do
          staff_upload = create(:certification_batch_upload, source_type: :ui)

          get api_certification_batch_upload_url(staff_upload),
              headers: auth_headers

          expect(response).to have_http_status(:not_found)
        end
      end

      it "returns 404 for non-existent ID" do
        with_batch_upload_v2_enabled do
          get api_certification_batch_upload_url(id: "00000000-0000-0000-0000-000000000000"),
              headers: auth_headers

          expect(response).to have_http_status(:not_found)
          expect(response.parsed_body["errors"]).to include("Not Found")
        end
      end
    end
  end
end
