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

  def initialize(certification_service: CertificationService.new, validator: BatchUploadRecordValidator.new)
    @certification_service = certification_service
    @validator = validator
  end

  # Process a single certification record
  # @param record [Hash] Record data with string keys
  # @param context [Hash] Optional context (e.g., batch_upload_id for origin tracking)
  # @return [Certification] The created certification
  # @raise [ValidationError] if required fields missing
  # @raise [DuplicateError] if certification already exists
  # @raise [DatabaseError] if save fails
  def process(record, context: {})
    validate_with_validator!(record)
    validate_schema!(record)
    check_duplicate!(record)
    persist!(record, context)
  end

  # Validate a record without persisting or raising
  # @param record [Hash] Record data with string keys
  # @return [Hash] { valid: true } or { valid: false, error_code:, error_message: }
  def validate_record(record)
    validate_with_validator!(record)
    validate_schema!(record)
    { valid: true }
  rescue ValidationError => e
    { valid: false, error_code: e.code, error_message: e.message }
  end

  # Batch duplicate check against existing database records (1 query)
  # @param records [Array<Hash>] Records with string keys
  # @return [Set<String>] Set of compound keys that already exist in the database
  def find_existing_duplicates(records)
    unique_member_ids = records.filter_map { |r| r["member_id"].presence }.uniq
    return Set.new if unique_member_ids.empty?

    existing_keys = Certification
      .where(member_id: unique_member_ids)
      .pluck(:member_id, :case_number, Arel.sql("certification_requirements->>'certification_date'"))
      .map { |mid, cn, cd| compound_key(mid, cn, cd) }

    existing_keys.to_set
  end

  # Generate a compound key for duplicate detection
  # @return [String] "member_id|case_number|certification_date"
  def compound_key(member_id, case_number, certification_date)
    "#{member_id}|#{case_number}|#{certification_date}"
  end

  # Bulk insert certifications and publish events
  # @param records [Array<Hash>] Validated, non-duplicate records with string keys
  # @param context [Hash] Context (e.g., batch_upload_id)
  # @return [Array<String>] IDs of created certifications
  def bulk_persist!(records, context)
    return [] if records.empty?

    now = Time.current

    cert_attrs = records.map do |record|
      cert = build_certification(record)
      {
        member_id: cert.member_id,
        case_number: cert.case_number,
        certification_requirements: cert.certification_requirements.as_json,
        member_data: cert.member_data&.as_json,
        created_at: now,
        updated_at: now
      }
    end

    certification_ids = nil
    Certification.transaction do
      result = Certification.insert_all!(cert_attrs, returning: %w[id])
      certification_ids = result.rows.flatten

      if context[:batch_upload_id]
        origin_attrs = certification_ids.map do |cert_id|
          {
            certification_id: cert_id,
            source_type: CertificationOrigin::SOURCE_TYPE_BATCH_UPLOAD,
            source_id: context[:batch_upload_id],
            created_at: now,
            updated_at: now
          }
        end
        CertificationOrigin.insert_all!(origin_attrs)
      end
    end

    # Publish events AFTER commit (matching after_create_commit semantics)
    certification_ids.each do |cert_id|
      Certification.publish_created_event(cert_id)
    rescue StandardError => e
      Rails.logger.error("Failed to publish CertificationCreated for cert #{cert_id}: #{e.message}")
    end

    certification_ids
  end

  private

  # Validate record with comprehensive validator (collect-all errors)
  def validate_with_validator!(record)
    result = @validator.validate(record)
    return if result.success?

    raise ValidationError.new(result.error_codes.first, result.error_messages.join("; "))
  end

  # Validate required fields are present (defense-in-depth safety net)
  # Extracted from CertificationBatchUploadService (lines 28-34)
  def validate_schema!(record)
    missing = REQUIRED_FIELDS - record.keys
    return if missing.empty?

    raise ValidationError.new(
      BatchUploadErrors::Validation::MISSING_FIELDS,
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
        BatchUploadErrors::Duplicate::EXISTING_CERTIFICATION,
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
    raise DatabaseError.new(BatchUploadErrors::Database::SAVE_FAILED, e.message)
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
