# frozen_string_literal: true

# Background job to process uploaded certification CSV files
class ProcessCertificationBatchUploadJob < ApplicationJob
  queue_as :default

  # Process a certification batch upload
  # @param batch_upload_id [String] The UUID of the CertificationBatchUpload record
  def perform(batch_upload_id)
    batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_upload_id)

    # Route to appropriate processing path based on feature flag
    if Features.batch_upload_v2_enabled?
      process_streaming(batch_upload)
    else
      process_from_active_storage(batch_upload) # Legacy sequential processing
    end

  rescue StandardError => e
    # Log error and mark batch as failed
    Rails.logger.error("Batch upload #{batch_upload_id} failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    batch_upload.fail_processing!(error_message: e.message) if batch_upload
    raise
  end

  private

  # V2: Streaming path with parallel chunk processing (requires feature flag)
  def process_streaming(batch_upload)
    batch_upload.start_processing!

    reader = CsvStreamReader.new
    total_records = 0

    # First pass: Count total rows
    reader.each_chunk(batch_upload.storage_key) do |records|
      total_records += records.size
    end

    # Set num_rows before enqueueing any jobs (prevents race condition)
    batch_upload.update!(num_rows: total_records)

    # Handle empty CSV (headers but no data)
    if total_records == 0
      batch_upload.complete_processing!(
        num_rows_succeeded: 0,
        num_rows_errored: 0,
        results: {}
      )
      return
    end

    # Second pass: Enqueue chunk jobs for parallel processing
    chunk_number = 0
    reader.each_chunk(batch_upload.storage_key) do |records|
      chunk_number += 1
      ProcessCertificationBatchChunkJob.perform_later(
        batch_upload.id,
        chunk_number,
        records
      )
    end
  end

  # V1: Sequential processing (legacy path, no parallel chunks)
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
