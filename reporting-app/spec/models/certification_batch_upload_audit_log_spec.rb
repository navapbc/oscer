# frozen_string_literal: true

require "rails_helper"

RSpec.describe CertificationBatchUploadAuditLog, type: :model do
  let(:user) { create(:user) }
  let(:batch_upload) { create(:certification_batch_upload, uploader: user, storage_key: "test-key") }

  describe "validations" do
    it "requires chunk_number" do
      log = described_class.new(certification_batch_upload: batch_upload)
      expect(log).not_to be_valid
      expect(log.errors[:chunk_number]).to be_present
    end

    it "requires chunk_number to be positive" do
      log = described_class.new(
        certification_batch_upload: batch_upload,
        chunk_number: 0
      )
      expect(log).not_to be_valid
      expect(log.errors[:chunk_number]).to include("must be greater than 0")
    end

    it "requires succeeded_count to be non-negative" do
      log = described_class.new(
        certification_batch_upload: batch_upload,
        chunk_number: 1,
        succeeded_count: -1
      )
      expect(log).not_to be_valid
    end

    it "requires failed_count to be non-negative" do
      log = described_class.new(
        certification_batch_upload: batch_upload,
        chunk_number: 1,
        failed_count: -1
      )
      expect(log).not_to be_valid
    end
  end

  describe "status enum" do
    let(:log) { create(:audit_log, certification_batch_upload: batch_upload, chunk_number: 1) }

    it "defaults to started" do
      expect(log.status).to eq("started")
      expect(log).to be_started
    end

    it "can transition to completed" do
      log.completed!
      expect(log).to be_completed
    end

    it "can transition to failed" do
      log.failed!
      expect(log).to be_failed
    end
  end

  describe "associations" do
    it "belongs to certification_batch_upload" do
      log = create(:audit_log, certification_batch_upload: batch_upload, chunk_number: 1)
      expect(log.certification_batch_upload).to eq(batch_upload)
    end

    it "is destroyed when batch_upload is destroyed" do
      log = create(:audit_log, certification_batch_upload: batch_upload, chunk_number: 1)
      # Eager load associations to avoid strict_loading violations
      batch_upload_with_associations = CertificationBatchUpload.includes(:audit_logs, :upload_errors).find(batch_upload.id)
      expect { batch_upload_with_associations.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
