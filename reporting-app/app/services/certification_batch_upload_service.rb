# frozen_string_literal: true

require "csv"

# Service for processing bulk certification uploads via CSV
class CertificationBatchUploadService
  attr_reader :results, :errors, :successes, :batch_upload

  def initialize(batch_upload: nil)
    @batch_upload = batch_upload
    @results = []
    @errors = []
    @successes = []
  end

  # Process uploaded CSV file and create certifications
  # @param file [ActionDispatch::Http::UploadedFile] The uploaded CSV file
  # @return [Boolean] True if processing completed (check results for individual success/failure)
  def process_csv(file)
    return false unless file.present?

    csv_data = CSV.read(file.path, headers: true, header_converters: :symbol)

    # Update total rows if batch_upload provided
    @batch_upload&.update!(num_rows: csv_data.size)

    # Validate required headers  
    required_headers = [:member_id, :case_number, :member_email, :certification_date, :certification_type]  
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
    # Check for duplicate certification (idempotency)
    if duplicate_certification?(row)
      @errors << {
        row: row_number,
        message: "Duplicate: Certification already exists for member_id #{row[:member_id]}, case_number #{row[:case_number]}, and certification_date #{row[:certification_date]}",
        data: row.to_h
      }
      @results << { row: row_number, status: :duplicate }
      return
    end

    # Build certification from CSV row
    certification = build_certification_from_row(row)

    ActiveRecord::Base.transaction do
      save_certification(certification, row, row_number)
    end
  rescue StandardError => e
    @errors << {
      row: row_number,
      message: e.message,
      data: row.to_h
    }
    @results << { row: row_number, status: :error, errors: e.message }
  end

  def build_certification_from_row(row)
    # Build member_data hash from CSV columns
    member_data = build_member_data(row)

    # Build certification requirements
    certification_requirements = build_certification_requirements(row)

    Certification.new(
      member_id: row[:member_id],
      case_number: row[:case_number],
      member_data: member_data,
      certification_requirements: certification_requirements
    )
  end

  def build_member_data(row)
    {
      "name" => {
        "first" => row[:first_name],
        "middle" => row[:middle_name],
        "last" => row[:last_name]
      }.compact_blank,
      "account_email" => row[:member_email],
      "contact" => {
        "email" => row[:member_email]
      }.compact_blank,
      "address" => row[:address],
      "county" => row[:county],
      "zip" => row[:zip_code],
      "date_of_birth" => row[:date_of_birth],
      "pregnancy_status" => row[:pregnancy_status],
      "race_ethnicity" => row[:race_ethnicity],
      "work_hours" => row[:work_hours],
      "other_income_sources" => row[:other_income_sources]
    }.compact_blank
  end

  def build_certification_requirements(row)
    certification_service = CertificationService.new

    # Build requirement params from CSV
    requirement_input = {
      "certification_date" => row[:certification_date],
      "certification_type" => row[:certification_type],
      "lookback_period" => row[:lookback_period]&.to_i,
      "number_of_months_to_certify" => row[:number_of_months_to_certify]&.to_i,
      "due_period_days" => row[:due_period_days]&.to_i
    }.compact_blank

    certification_service.certification_requirements_from_input(requirement_input)
  end

  # Check if certification already exists (for idempotency)
  # Uses compound key: member_id + case_number + certification_date
  def duplicate_certification?(row)
    return false if row[:member_id].blank? || row[:case_number].blank? || row[:certification_date].blank?

    Certification.exists_for?(
      member_id: row[:member_id],
      case_number: row[:case_number],
      certification_date: row[:certification_date]
    )
  end

  def save_certification(certification, row, row_number)
    if certification.save
      # Track origin if batch_upload provided
      if @batch_upload
        CertificationOrigin.create!(
          certification_id: certification.id,
          source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
          source_id: @batch_upload.id
        )
      end

      @successes << {
        row: row_number,
        case_number: certification.case_number,
        member_id: certification.member_id,
        certification_id: certification.id
      }
      @results << { row: row_number, status: :success, certification_id: certification.id }
    else
      error_messages = certification.errors.full_messages.join(", ")
      @errors << {
        row: row_number,
        message: error_messages,
        data: row.to_h
      }
      @results << { row: row_number, status: :error, errors: certification.errors }
    end
  end
end
