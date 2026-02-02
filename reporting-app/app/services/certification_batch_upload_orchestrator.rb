# frozen_string_literal: true

class CertificationBatchUploadOrchestrator
  class FileNotFoundError < StandardError; end

  def initialize(storage_adapter: nil)
    @storage = storage_adapter || Rails.application.config.storage_adapter
  end

  # Initiate batch upload processing
  # @param source_type [Symbol] How file was uploaded (:ui, :api, :storage_event)
  # @param filename [String] Original filename
  # @param storage_key [String] Cloud storage object key
  # @param uploader [User] User who initiated the upload
  # @param metadata [Hash] Optional metadata (reserved for future use)
  # @return [CertificationBatchUpload] Created batch upload record
  # @raise [FileNotFoundError] if file doesn't exist in storage
  def initiate(source_type:, filename:, storage_key:, uploader:, metadata: {})
    # Validate file exists in cloud storage before creating DB record
    unless @storage.object_exists?(key: storage_key)
      raise FileNotFoundError, "File not found in storage: #{storage_key}"
    end

    # Create batch upload record
    batch_upload = CertificationBatchUpload.create!(
      source_type: source_type,
      filename: filename,
      storage_key: storage_key,
      uploader: uploader,
      status: :pending
    )

    # Enqueue processing job for async execution
    ProcessCertificationBatchUploadJob.perform_later(batch_upload.id)

    batch_upload
  end
end
