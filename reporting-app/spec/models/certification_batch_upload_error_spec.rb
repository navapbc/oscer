# frozen_string_literal: true

require "rails_helper"

RSpec.describe CertificationBatchUploadError, type: :model do
  let(:user) { create(:user) }
  let(:batch_upload) { create(:certification_batch_upload, uploader: user, storage_key: "test-key") }

  describe "validations" do
    it "requires row_number" do
      error = described_class.new(
        certification_batch_upload: batch_upload,
        error_code: "VAL_001",
        error_message: "Missing field"
      )
      expect(error).not_to be_valid
      expect(error.errors[:row_number]).to be_present
    end

    it "requires row_number to be positive" do
      error = described_class.new(
        certification_batch_upload: batch_upload,
        row_number: 0,
        error_code: "VAL_001",
        error_message: "Missing field"
      )
      expect(error).not_to be_valid
      expect(error.errors[:row_number]).to include("must be greater than 0")
    end

    it "requires error_code" do
      error = described_class.new(
        certification_batch_upload: batch_upload,
        row_number: 1,
        error_message: "Missing field"
      )
      expect(error).not_to be_valid
      expect(error.errors[:error_code]).to be_present
    end

    it "requires error_message" do
      error = described_class.new(
        certification_batch_upload: batch_upload,
        row_number: 1,
        error_code: "VAL_001"
      )
      expect(error).not_to be_valid
      expect(error.errors[:error_message]).to be_present
    end
  end

  describe "creating errors" do
    it "creates with valid attributes" do
      error = create(:upload_error, certification_batch_upload: batch_upload, row_number: 42)

      expect(error).to be_persisted
      expect(error.row_number).to eq(42)
      expect(error.error_code).to eq("VAL_001")
      expect(error.error_message).to be_present
    end

    it "stores row_data as JSONB" do
      row_data = { "member_id" => "M123", "name" => "Test" }
      error = create(:upload_error, certification_batch_upload: batch_upload, row_data: row_data)

      expect(error.row_data).to eq(row_data)
    end

    it "allows nil row_data" do
      error = create(:upload_error, certification_batch_upload: batch_upload, row_data: nil)

      expect(error).to be_valid
      expect(error.row_data).to be_nil
    end
  end

  describe "associations" do
    it "belongs to certification_batch_upload" do
      error = create(:upload_error, certification_batch_upload: batch_upload)
      expect(error.certification_batch_upload).to eq(batch_upload)
    end

    it "is destroyed when batch_upload is destroyed" do
      error = create(:upload_error, certification_batch_upload: batch_upload)
      # Eager load associations to avoid strict_loading violations
      batch_upload_with_associations = CertificationBatchUpload.includes(:audit_logs, :upload_errors).find(batch_upload.id)
      expect { batch_upload_with_associations.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
