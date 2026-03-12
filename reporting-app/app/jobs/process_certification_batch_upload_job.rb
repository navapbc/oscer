# frozen_string_literal: true

# Background job to process uploaded certification CSV files
class ProcessCertificationBatchUploadJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  # Process a certification batch upload
  # @param batch_upload_id [String] The UUID of the CertificationBatchUpload record
  def perform(batch_upload_id)
    batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_upload_id)

    process_streaming(batch_upload)

  rescue StandardError => e
    # Log error and mark batch as failed
    Rails.logger.error("Batch upload #{batch_upload_id} failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    batch_upload.fail_processing!(error_message: e.message) if batch_upload
    raise
  end

  private

  # Streaming path with parallel chunk processing
  def process_streaming(batch_upload)
    batch_upload.start_processing!

    reader = CsvStreamReader.new
    total_records = 0
    chunks = []

    # Single pass: count records and collect byte-range coordinates
    reader.each_chunk_with_offsets(batch_upload.storage_key) do |records, headers, start_byte, end_byte|
      total_records += records.size
      chunks << {
        chunk_number: chunks.size + 1,
        headers: headers,
        start_byte: start_byte,
        end_byte: end_byte,
        record_count: records.size
      }
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

    # Enqueue chunk jobs with byte coordinates (not data)
    chunks.each do |chunk|
      ProcessCertificationBatchChunkJob.perform_later(
        batch_upload.id,
        chunk[:chunk_number],
        chunk[:headers],
        chunk[:start_byte],
        chunk[:end_byte],
        chunk[:record_count]
      )
    end
  end
end
