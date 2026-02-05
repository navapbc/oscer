# frozen_string_literal: true

# Background job to process uploaded certification CSV files
class ProcessCertificationBatchUploadJob < ApplicationJob
  queue_as :default

  # Process a certification batch upload
  # @param batch_upload_id [String] The UUID of the CertificationBatchUpload record
  def perform(batch_upload_id)
    batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_upload_id)

    # Route to appropriate processing path based on upload type and feature flag
    # TODO: Simplify to only process_streaming when FEATURE_BATCH_UPLOAD_V2 flag is removed
    if Features.batch_upload_v2_enabled? && batch_upload.uses_cloud_storage?
      process_streaming(batch_upload)
    elsif batch_upload.uses_cloud_storage?
      process_from_cloud_storage_sequential(batch_upload) # TODO: Remove - temporary fallback
    elsif batch_upload.uses_active_storage?
      process_from_active_storage(batch_upload) # TODO: Remove - legacy v1 path
    else
      batch_upload.fail_processing!(
        error_message: "Invalid upload state: missing both file attachment and storage key"
      )
    end

  rescue StandardError => e
    # Log error and mark batch as failed
    Rails.logger.error("Batch upload #{batch_upload_id} failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    batch_upload.fail_processing!(error_message: e.message) if batch_upload
    raise
  end

  private

  # NEW: Streaming path for v2 uploads (only when feature flag enabled)
  # This will become the ONLY processing path once feature flag is removed
  def process_streaming(batch_upload)
    batch_upload.start_processing!

    reader = CsvStreamReader.new
    chunk_number = 0
    total_records = 0

    reader.each_chunk(batch_upload.storage_key) do |records|
      chunk_number += 1
      total_records += records.size

      ProcessCertificationBatchChunkJob.perform_later(
        batch_upload.id,
        chunk_number,
        records
      )
    end

    batch_upload.update!(num_rows: total_records)
  rescue StandardError => e
    batch_upload.fail_processing!(error_message: e.message)
    raise
  end

  # FALLBACK: Cloud storage but flag disabled - download and process sequentially
  # TODO: Remove this method when FEATURE_BATCH_UPLOAD_V2 flag is removed
  # This is a temporary safety fallback during v2 rollout
  def process_from_cloud_storage_sequential(batch_upload)
    batch_upload.start_processing!

    temp_file = Tempfile.new([ "batch_upload", ".csv" ], encoding: "UTF-8")
    begin
      # Download from cloud storage to temp file
      storage_adapter = Rails.application.config.storage_adapter
      storage_adapter.download_to_file(key: batch_upload.storage_key, file: temp_file)
      temp_file.rewind

      # Process using existing service (v1 style)
      service = CertificationBatchUploadService.new(batch_upload: batch_upload)
      success = service.process_csv(temp_file)

      handle_service_result(batch_upload, service, success)
    ensure
      temp_file.close
      temp_file.unlink
    end
  rescue StandardError => e
    batch_upload.fail_processing!(error_message: e.message)
    raise
  end

  # EXISTING: Active Storage path (preserved for backward compatibility)
  # TODO: Remove this method when FEATURE_BATCH_UPLOAD_V2 flag is removed
  # After flag removal, all uploads will use cloud storage (v2)
  def process_from_active_storage(batch_upload)
    batch_upload.start_processing!

    temp_file = Tempfile.new([ "batch_upload", ".csv" ], encoding: "UTF-8")
    begin
      temp_file.write(batch_upload.file.download.force_encoding("UTF-8"))
      temp_file.rewind

      service = CertificationBatchUploadService.new(batch_upload: batch_upload)
      success = service.process_csv(temp_file)

      handle_service_result(batch_upload, service, success)
    ensure
      temp_file.close
      temp_file.unlink
    end
  rescue StandardError => e
    batch_upload.fail_processing!(error_message: e.message)
    raise
  end

  def handle_service_result(batch_upload, service, success)
    if success
      # Store results and mark complete
      batch_upload.complete_processing!(
        num_rows_succeeded: service.successes.count,
        num_rows_errored: service.errors.count,
        results: {
          successes: service.successes,
          errors: service.errors
        }
      )
    else
      # Mark as failed
      batch_upload.fail_processing!(
        error_message: service.errors.first&.dig(:message) || "Unknown error"
      )
    end
  end
end
