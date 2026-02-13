# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AuthenticatedDirectUploads", type: :request do
  include Warden::Test::Helpers

  describe "POST /rails/active_storage/direct_uploads" do
    let(:blob_args) do
      {
        filename: "test.csv",
        byte_size: 1024,
        checksum: Digest::MD5.base64digest("test content"),
        content_type: "text/csv"
      }
    end

    context "when user is authenticated" do
      let(:user) { create(:user) }

      before do
        login_as user
      end

      it "creates a direct upload" do
        post "/rails/active_storage/direct_uploads", params: { blob: blob_args }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key("direct_upload")
        expect(json["direct_upload"]).to have_key("url")
        expect(json["direct_upload"]).to have_key("headers")
      end

      it "creates an ActiveStorage::Blob record" do
        expect {
          post "/rails/active_storage/direct_uploads", params: { blob: blob_args }, as: :json
        }.to change(ActiveStorage::Blob, :count).by(1)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized" do
        post "/rails/active_storage/direct_uploads", params: { blob: blob_args }, as: :json

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Authentication required")
      end

      it "does not create a blob" do
        expect {
          post "/rails/active_storage/direct_uploads", params: { blob: blob_args }, as: :json
        }.not_to change(ActiveStorage::Blob, :count)
      end
    end
  end
end
