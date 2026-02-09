# frozen_string_literal: true

require "csv"

# Service for processing bulk certification uploads via CSV
class CertificationBatchUploadService
  attr_reader :results, :errors, :successes, :batch_upload

  def initialize(batch_upload: nil, processor: UnifiedRecordProcessor.new)
    @batch_upload = batch_upload
    @processor = processor
    @results = []
    @errors = []
    @successes = []
  end

  # Process uploaded CSV file and create certifications
  # @param file [ActionDispatch::Http::UploadedFile] The uploaded CSV file
  # @return [Boolean] True if processing completed (check results for individual success/failure)
  def process_csv(file)
    return false unless file.present?

    csv_data = CSV.read(file.path, headers: true, encoding: "UTF-8")

    # Update total rows if batch_upload provided
    @batch_upload&.update!(num_rows: csv_data.size)

    # Validate required headers (CSV structure check - fails fast before chunk processing)
    # Shares field list with UnifiedRecordProcessor for consistency
    required_headers = UnifiedRecordProcessor::REQUIRED_FIELDS
    missing_headers = required_headers - csv_data.headers

    if missing_headers.any?
      @errors << { row: 0, message: "Missing required columns: #{missing_headers.join(', ')}" }
      return false
    end

    csv_data.each_with_index do |row, index|
      process_row(row, index + 2) # +2 for header row and 0-indexing

      # Update progress every 10 rows
      if @batch_upload && (index + 1) % 10 == 0
        @batch_upload.update_progress!(num_rows_processed: index + 1)
      end
    end

    # Final progress update
    @batch_upload&.update_progress!(num_rows_processed: csv_data.size)

    true
  rescue CSV::MalformedCSVError => e
    @errors << { row: 0, message: "Invalid CSV format: #{e.message}" }
    false
  rescue StandardError => e
    @errors << { row: 0, message: "Unexpected error: #{e.message}" }
    false
  end

  # Total number of rows processed
  def total_processed
    @successes.count + @errors.count
  end

  # Whether all rows succeeded
  def all_succeeded?
    @errors.empty? && @successes.any?
  end

  private

  def process_row(row, row_number)
    # Delegate to UnifiedRecordProcessor for consistent business logic
    context = @batch_upload ? { batch_upload_id: @batch_upload.id } : {}
    certification = @processor.process(row.to_h, context: context)

    @successes << {
      row: row_number,
      case_number: certification.case_number,
      member_id: certification.member_id,
      certification_id: certification.id
    }
    @results << { row: row_number, status: :success, certification_id: certification.id }

  rescue UnifiedRecordProcessor::DuplicateError => e
    @errors << { row: row_number, message: e.message, data: row.to_h }
    @results << { row: row_number, status: :duplicate }
  rescue UnifiedRecordProcessor::ProcessingError => e
    @errors << { row: row_number, message: e.message, data: row.to_h }
    @results << { row: row_number, status: :error, errors: e.message }
  rescue StandardError => e
    @errors << { row: row_number, message: e.message, data: row.to_h }
    @results << { row: row_number, status: :error, errors: e.message }
  end
end
