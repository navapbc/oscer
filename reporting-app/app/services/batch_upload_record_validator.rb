# frozen_string_literal: true

# Validates individual certification records for batch uploads
# Performs comprehensive field-level validation before processing
# Returns structured ValidationResult with error codes from BatchUploadErrors
#
# Validation rules (fail-fast, returns on first error):
# 1. Required fields present
# 2. Date formats (YYYY-MM-DD + parseability)
# 3. Email format (RFC 5322)
# 4. Certification type enum
# 5. Integer fields (positive integers)
class BatchUploadRecordValidator
  # Required fields for all certification records
  REQUIRED_FIELDS = UnifiedRecordProcessor::REQUIRED_FIELDS

  # Allowed certification types
  CERTIFICATION_TYPES = %w[new_application recertification].freeze

  # Email validation regex (RFC 5322 compatible)
  EMAIL_REGEX = URI::MailTo::EMAIL_REGEXP

  # Date format regex (YYYY-MM-DD)
  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

  # Integer format regex (positive integers only)
  INTEGER_FORMAT = /\A\d+\z/

  # Date fields to validate
  DATE_FIELDS = %w[certification_date].freeze
  OPTIONAL_DATE_FIELDS = %w[date_of_birth].freeze

  # Integer fields to validate (when present)
  INTEGER_FIELDS = %w[lookback_period number_of_months_to_certify due_period_days work_hours].freeze

  # Result structure for validation outcome
  # Note: Using `success?` instead of `valid?` to avoid shadowing Rails' `valid?` convention
  ValidationResult = Struct.new(:success?, :error_code, :error_message, keyword_init: true) do
    def self.success
      new(success?: true, error_code: nil, error_message: nil)
    end

    def self.error(code, message)
      new(success?: false, error_code: code, error_message: message)
    end
  end

  # Validate a single record
  # @param record [Hash] Record data with string keys
  # @return [ValidationResult] Validation outcome with error details if invalid
  def validate(record)
    validate_required_fields(record) ||
      validate_date_formats(record) ||
      validate_email_format(record) ||
      validate_certification_type(record) ||
      validate_integer_fields(record) ||
      ValidationResult.success
  end

  private

  # Validate all required fields are present
  def validate_required_fields(record)
    missing = REQUIRED_FIELDS - record.keys
    return nil if missing.empty?

    ValidationResult.error(
      BatchUploadErrors::Validation::MISSING_FIELDS,
      "Missing required fields: #{missing.join(', ')}"
    )
  end

  # Validate date field formats and parseability
  def validate_date_formats(record)
    # Validate required date fields
    DATE_FIELDS.each do |field|
      result = validate_date_field(record, field)
      return result if result
    end

    # Validate optional date fields (only if present)
    OPTIONAL_DATE_FIELDS.each do |field|
      next if record[field].blank?

      result = validate_date_field(record, field)
      return result if result
    end

    nil
  end

  # Validate a single date field
  def validate_date_field(record, field)
    value = record[field]

    # Check format (YYYY-MM-DD)
    unless value.match?(DATE_FORMAT)
      return ValidationResult.error(
        BatchUploadErrors::Validation::INVALID_DATE,
        "Field '#{field}' has invalid date format '#{value}'. Expected YYYY-MM-DD (e.g., 2025-01-15)"
      )
    end

    # Check parseability
    Date.parse(value)
    nil
  rescue Date::Error
    ValidationResult.error(
      BatchUploadErrors::Validation::INVALID_DATE,
      "Field '#{field}' has unparseable date '#{value}'. Expected valid date in YYYY-MM-DD format"
    )
  end

  # Validate email format
  def validate_email_format(record)
    email = record["member_email"]
    return nil if email.blank? # Already caught by required fields validation

    unless email.match?(EMAIL_REGEX)
      return ValidationResult.error(
        BatchUploadErrors::Validation::INVALID_EMAIL,
        "Field 'member_email' has invalid email format '#{email}'. Expected valid email (e.g., user@example.com)"
      )
    end

    nil
  end

  # Validate certification type is in allowed values
  def validate_certification_type(record)
    cert_type = record["certification_type"]
    return nil if cert_type.blank? # Already caught by required fields validation

    unless CERTIFICATION_TYPES.include?(cert_type)
      return ValidationResult.error(
        BatchUploadErrors::Validation::INVALID_TYPE,
        "Field 'certification_type' has invalid value '#{cert_type}'. " \
        "Allowed values: #{CERTIFICATION_TYPES.join(', ')}"
      )
    end

    nil
  end

  # Validate integer fields (when present)
  def validate_integer_fields(record)
    INTEGER_FIELDS.each do |field|
      value = record[field]
      next if value.blank? # Optional fields

      unless value.to_s.match?(INTEGER_FORMAT)
        return ValidationResult.error(
          BatchUploadErrors::Validation::INVALID_INTEGER,
          "Field '#{field}' has invalid integer value '#{value}'. Expected positive integer (e.g., 30)"
        )
      end
    end

    nil
  end
end
