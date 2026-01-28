# frozen_string_literal: true

# Background job to process uploaded certification CSV files
class ProcessCertificationBatchUploadJob < ApplicationJob
  queue_as :default

  # Process a certification batch upload
  # @param batch_upload_id [String] The UUID of the CertificationBatchUpload record
  def perform(batch_upload_id)
    batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_upload_id)

    # Guard: V2 uploads not yet supported
    # TODO: Remove this guard when v2 processing is implemented (Stories 1-3)
    if batch_upload.uses_cloud_storage?
      batch_upload.fail_processing!(
        error_message: "Batch upload v2 is not yet implemented"
      )
      return
    end

    # Guard: Ensure valid v1 upload
    unless batch_upload.uses_active_storage?
      batch_upload.fail_processing!(
        error_message: "Invalid upload state: missing file attachment"
      )
      return
    end

    # V1 upload processing (ActiveStorage)
    # Mark as processing
    batch_upload.start_processing!

    # Download attached file to temporary location
    temp_file = Tempfile.new([ "batch_upload", ".csv" ], encoding: "UTF-8")
    begin
      temp_file.write(batch_upload.file.download.force_encoding("UTF-8"))
      temp_file.rewind

      # Process the CSV
      service = CertificationBatchUploadService.new(batch_upload: batch_upload)
      success = service.process_csv(temp_file)

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
    ensure
      temp_file.close
      temp_file.unlink
    end

  rescue StandardError => e
    # Log error and mark batch as failed
    Rails.logger.error("Batch upload #{batch_upload_id} failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    batch_upload.fail_processing!(error_message: e.message) if batch_upload
    raise
  end
end
