# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/api/direct_uploads", type: :request do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  let(:valid_params) do
    {
      blob: {
        filename: "test_upload.csv",
        byte_size: 1024,
        checksum: Base64.strict_encode64(Digest::MD5.digest("test")),
        content_type: "text/csv"
      }
    }
  end

  def auth_headers(params = nil)
    body = params ? params.to_json : ""
    hmac_auth_headers(body: body, secret: Rails.configuration.api_secret_key)
  end

  describe "POST /api/direct_uploads" do
    context "when batch_upload_v2 flag is disabled" do
      it "returns 404" do
        with_batch_upload_v2_disabled do
          post api_direct_uploads_url,
               params: valid_params,
               headers: auth_headers(valid_params),
               as: :json

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when batch_upload_v2 flag is enabled" do
      it "returns 401 without HMAC auth" do
        with_batch_upload_v2_enabled do
          post api_direct_uploads_url,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end

      it "returns 401 with Devise session but no HMAC" do
        with_batch_upload_v2_enabled do
          admin = create(:user, :as_admin)

          # Simulate Devise session by setting Warden user
          login_as(admin, scope: :user)

          post api_direct_uploads_url,
               params: valid_params,
               as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end

      it "returns a presigned URL with valid HMAC auth" do
        with_batch_upload_v2_enabled do
          post api_direct_uploads_url,
               params: valid_params,
               headers: auth_headers(valid_params),
               as: :json

          expect(response).to have_http_status(:ok)
          body = response.parsed_body
          expect(body["signed_id"]).to be_present
          expect(body["direct_upload"]).to be_present
          expect(body["direct_upload"]["url"]).to be_present
        end
      end
    end
  end
end
