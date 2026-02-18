# frozen_string_literal: true

# Background job to process a single chunk of certification records
# Part of batch upload v2 streaming architecture - processes chunks in parallel
class ProcessCertificationBatchChunkJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 3

  # Process a chunk of certification records
  # @param batch_upload_id [String] The UUID of the CertificationBatchUpload record
  # @param chunk_number [Integer] The sequential chunk number (1-indexed)
  # @param records [Array<Hash>] Array of record hashes to process
  # @param processor [UnifiedRecordProcessor] The processor to use (injectable for testing)
  def perform(batch_upload_id, chunk_number, records, processor: UnifiedRecordProcessor.new)
    batch_upload = CertificationBatchUpload.find_by(id: batch_upload_id)
    return if batch_upload.nil?  # Batch was deleted, nothing to do
    audit_log = create_audit_log(batch_upload, chunk_number)

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
    store_errors!(batch_upload, results[:errors])
    check_completion!(batch_upload)

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
    batch_upload.with_lock do
      batch_upload.increment!(:num_rows_processed, record_count)
      batch_upload.increment!(:num_rows_succeeded, results[:succeeded])
      batch_upload.increment!(:num_rows_errored, results[:failed])
    end
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

  # Check if batch is complete and transition to completed state
  # Uses pessimistic lock with retry to handle concurrent chunk completion
  def check_completion!(batch_upload)
    retries = 0
    begin
      batch_upload.with_lock do
        return unless batch_upload.num_rows_processed >= batch_upload.num_rows
        return if batch_upload.completed?

        batch_upload.complete_processing!(
          num_rows_succeeded: batch_upload.num_rows_succeeded,
          num_rows_errored: batch_upload.num_rows_errored,
          results: {} # Results now in audit_logs and upload_errors tables
        )
      end
    rescue ActiveRecord::LockWaitTimeout => e
      retries += 1
      if retries < 3
        Rails.logger.info("Lock timeout on completion check (attempt #{retries}/3), retrying after backoff")
        # Use sleep rather than ActiveJob retry_on: retry_on restarts the entire job,
        # re-processing all records and losing completed work. We only need to retry
        # this specific lock acquisition, not the whole job.
        sleep(2**retries) # Exponential backoff: 2s, 4s, 8s
        retry
      else
        Rails.logger.error("Failed to acquire completion lock after 3 retries: #{e.message}")
        raise
      end
    end
  end
end
