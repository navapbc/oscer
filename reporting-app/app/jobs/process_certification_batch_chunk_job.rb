# frozen_string_literal: true

# Background job to process a single chunk of certification records in parallel
class ProcessCertificationBatchChunkJob < ApplicationJob
  queue_as :default

  # When a chunk is discarded (any unhandled error), report in as failed so the
  # batch can reach a terminal state. All rows are counted as errored.
  # The @counters_updated flag prevents double-counting if the error happened
  # after update_counters! already ran in perform.
  discard_on StandardError do |job, error|
    batch_upload_id, chunk_number, _headers, _start_byte, _end_byte, record_count = job.arguments
    batch_upload = CertificationBatchUpload.find_by(id: batch_upload_id)
    next unless batch_upload && record_count

    Rails.logger.error(
      "Chunk #{chunk_number} for batch #{batch_upload_id} discarded: #{error.class} - #{error.message}"
    )

    unless job.counters_updated
      CertificationBatchUpload.update_counters(
        batch_upload.id,
        num_rows_processed: record_count,
        num_rows_errored: record_count
      )
    end

    batch_upload.check_completion!
  end

  attr_reader :counters_updated

  # Process a chunk of certification records by reading from S3
  # @param batch_upload_id [String] The UUID of the CertificationBatchUpload record
  # @param chunk_number [Integer] The sequential chunk number (1-indexed)
  # @param headers [Array<String>] CSV column headers
  # @param start_byte [Integer] Start of byte range in S3 object (inclusive)
  # @param end_byte [Integer] End of byte range in S3 object (inclusive)
  # @param record_count [Integer] Number of records in this chunk (for failure reporting)
  # @param processor [UnifiedRecordProcessor] The processor to use (injectable for testing)
  def perform(batch_upload_id, chunk_number, headers, start_byte, end_byte, record_count, processor: UnifiedRecordProcessor.new)
    @counters_updated = false

    batch_upload = CertificationBatchUpload.find_by(id: batch_upload_id)
    return if batch_upload.nil?  # Batch was deleted, nothing to do
    audit_log = create_audit_log(batch_upload, chunk_number)

    storage_key = batch_upload.storage_key
    Rails.logger.info("Chunk #{chunk_number} for batch #{batch_upload_id}: reading key=#{storage_key} bytes=#{start_byte}-#{end_byte}")

    # Read records from S3 using byte-range coordinates
    reader = CsvStreamReader.new
    records = reader.read_chunk(
      storage_key,
      headers: headers,
      start_byte: start_byte,
      end_byte: end_byte
    )

    results = { succeeded: 0, failed: 0, errors: [] }
    context = { batch_upload_id: batch_upload.id }

    records.each_with_index do |record, index|
      row_number = calculate_row_number(chunk_number, index)

      begin
        processor.process(record, context: context)
        results[:succeeded] += 1
      rescue UnifiedRecordProcessor::ProcessingError => e
        results[:failed] += 1
        results[:errors] << {
          row_number: row_number,
          error_code: e.code,
          error_message: e.message,
          row_data: record
        }
      rescue StandardError => e
        # Catch unexpected errors (shouldn't happen, but safety net)
        Rails.logger.error("Unexpected error processing row #{row_number}: #{e.class} - #{e.message}")
        Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
        results[:failed] += 1
        results[:errors] << {
          row_number: row_number,
          error_code: BatchUploadErrors::Unknown::UNEXPECTED,
          error_message: "Unexpected error: #{e.class} - #{e.message}",
          row_data: record
        }
      end
    end

    complete_audit_log(audit_log, results)
    update_counters!(batch_upload, records.size, results)
    @counters_updated = true
    store_errors!(batch_upload, results[:errors])
    batch_upload.check_completion!

  rescue StandardError => e
    # Mark audit log as failed if chunk job crashes (system error)
    audit_log&.update!(status: :failed) if audit_log
    Rails.logger.error("Chunk #{chunk_number} for batch #{batch_upload_id} failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def create_audit_log(batch_upload, chunk_number)
    CertificationBatchUploadAuditLog.create!(
      certification_batch_upload: batch_upload,
      chunk_number: chunk_number,
      status: :started,
      succeeded_count: 0,
      failed_count: 0
    )
  end

  def complete_audit_log(audit_log, results)
    audit_log.update!(
      status: :completed,
      succeeded_count: results[:succeeded],
      failed_count: results[:failed]
    )
  end

  def calculate_row_number(chunk_number, index)
    # chunk_number is 1-indexed, index is 0-indexed
    # Add 2 to account for CSV header row
    ((chunk_number - 1) * CsvStreamReader::DEFAULT_CHUNK_SIZE) + index + 2
  end

  def update_counters!(batch_upload, record_count, results)
    CertificationBatchUpload.update_counters(
      batch_upload.id,
      num_rows_processed: record_count,
      num_rows_succeeded: results[:succeeded],
      num_rows_errored: results[:failed]
    )
  end

  def store_errors!(batch_upload, errors)
    return if errors.empty?

    error_records = errors.map do |error|
      {
        certification_batch_upload_id: batch_upload.id,
        row_number: error[:row_number],
        error_code: error[:error_code],
        error_message: error[:error_message],
        row_data: error[:row_data],
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    CertificationBatchUploadError.insert_all(error_records)
  end
end
