# frozen_string_literal: true

# Unified processor for certification records from any source (batch, API, etc.)
# Extracts business logic from CertificationBatchUploadService to ensure
# all upload sources apply identical validation and processing rules.
class UnifiedRecordProcessor
  # Base error class for all processing errors
  class ProcessingError < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  # Raised when record fails schema validation
  class ValidationError < ProcessingError; end

  # Raised when record is a duplicate
  class DuplicateError < ProcessingError; end

  # Raised when database operation fails
  class DatabaseError < ProcessingError; end

  # Required fields for all certification records
  REQUIRED_FIELDS = %w[member_id case_number member_email certification_date certification_type].freeze

  def initialize(certification_service: CertificationService.new)
    @certification_service = certification_service
  end

  # Process a single certification record
  # @param record [Hash] Record data with string keys
  # @param context [Hash] Optional context (e.g., batch_upload_id for origin tracking)
  # @return [Certification] The created certification
  # @raise [ValidationError] if required fields missing
  # @raise [DuplicateError] if certification already exists
  # @raise [DatabaseError] if save fails
  def process(record, context: {})
    validate_schema!(record)
    check_duplicate!(record)
    persist!(record, context)
  end

  private

  # Validate required fields are present
  # Extracted from CertificationBatchUploadService (lines 28-34)
  def validate_schema!(record)
    missing = REQUIRED_FIELDS - record.keys
    return if missing.empty?

    raise ValidationError.new(
      "VAL_001",
      "Missing required fields: #{missing.join(', ')}"
    )
  end

  # Check if certification already exists (idempotency)
  # Extracted from CertificationBatchUploadService#duplicate_certification? (lines 150-158)
  def check_duplicate!(record)
    return if record["member_id"].blank? || record["case_number"].blank? || record["certification_date"].blank?

    if Certification.exists_for?(
      member_id: record["member_id"],
      case_number: record["case_number"],
      certification_date: record["certification_date"]
    )
      raise DuplicateError.new(
        "DUP_001",
        "Duplicate certification for member_id #{record['member_id']}, " \
        "case_number #{record['case_number']}, certification_date #{record['certification_date']}"
      )
    end
  end

  # Build and persist certification with origin tracking
  # Extracted from CertificationBatchUploadService#save_certification (lines 160-187)
  def persist!(record, context)
    certification = build_certification(record)

    ActiveRecord::Base.transaction do
      certification.save!

      # Track origin if batch_upload context provided
      if context[:batch_upload_id]
        CertificationOrigin.create!(
          certification_id: certification.id,
          source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
          source_id: context[:batch_upload_id]
        )
      end
    end

    certification
  rescue ActiveRecord::RecordInvalid => e
    raise DatabaseError.new("DB_001", e.message)
  end

  # Build certification object from record
  # Extracted from CertificationBatchUploadService#build_certification_from_row (lines 96-109)
  def build_certification(record)
    Certification.new(
      member_id: record["member_id"],
      case_number: record["case_number"],
      member_data: build_member_data(record),
      certification_requirements: build_certification_requirements(record)
    )
  end

  # Build member_data hash from record fields
  # Extracted from CertificationBatchUploadService#build_member_data (lines 111-131)
  def build_member_data(record)
    {
      "name" => {
        "first" => record["first_name"],
        "middle" => record["middle_name"],
        "last" => record["last_name"]
      }.compact_blank,
      "account_email" => record["member_email"],
      "contact" => {
        "email" => record["member_email"]
      }.compact_blank,
      "address" => record["address"],
      "county" => record["county"],
      "zip" => record["zip_code"],
      "date_of_birth" => record["date_of_birth"],
      "pregnancy_status" => record["pregnancy_status"],
      "race_ethnicity" => record["race_ethnicity"],
      "work_hours" => record["work_hours"],
      "other_income_sources" => record["other_income_sources"]
    }.compact_blank
  end

  # Build certification_requirements hash from record fields
  # Extracted from CertificationBatchUploadService#build_certification_requirements (lines 133-146)
  def build_certification_requirements(record)
    requirement_input = {
      "certification_date" => record["certification_date"],
      "certification_type" => record["certification_type"],
      "lookback_period" => record["lookback_period"]&.to_i,
      "number_of_months_to_certify" => record["number_of_months_to_certify"]&.to_i,
      "due_period_days" => record["due_period_days"]&.to_i
    }.compact_blank

    @certification_service.certification_requirements_from_input(requirement_input)
  end
end
