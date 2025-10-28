# frozen_string_literal: true

# Background job to process uploaded certification CSV files
class ProcessCertificationBatchUploadJob < ApplicationJob
  queue_as :default

  # Process a certification batch upload
  # @param batch_upload_id [String] The UUID of the CertificationBatchUpload record
  def perform(batch_upload_id)
    batch_upload = CertificationBatchUpload.includes(file_attachment: :blob).find(batch_upload_id)

    # Mark as processing
    batch_upload.start_processing!

    # Download attached file to temporary location
    temp_file = Tempfile.new([ "batch_upload", ".csv" ])
    begin
      temp_file.write(batch_upload.file.download)
      temp_file.rewind

      # Process the CSV
      service = CertificationBatchUploadService.new(batch_upload: batch_upload)
      success = service.process_csv(temp_file)

      if success
        # Store results and mark complete
        batch_upload.complete_processing!(
          success_count: service.successes.count,
          error_count: service.errors.count,
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
