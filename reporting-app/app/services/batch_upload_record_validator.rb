# frozen_string_literal: true

# Validates individual certification records for batch uploads
# Performs comprehensive field-level validation before processing
# Returns structured ValidationResult with error codes from BatchUploadErrors
#
# Validation rules (collect-all, returns all errors found):
# 1. Required fields present and not blank (blank values treated as missing)
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
  ValidationResult = Struct.new(:success?, :error_codes, :error_messages, keyword_init: true) do
    def self.success
      new(success?: true, error_codes: [], error_messages: [])
    end

    def self.failure(errors)
      new(
        success?: false,
        error_codes: errors.map { |e| e[:code] },
        error_messages: errors.map { |e| e[:message] }
      )
    end
  end

  # Validate a single record, collecting all errors
  # @param record [Hash] Record data with string keys
  # @return [ValidationResult] Validation outcome with all error details if invalid
  def validate(record)
    errors = []
    errors.concat(validate_required_fields(record))
    errors.concat(validate_date_formats(record))
    errors.concat(validate_email_format(record))
    errors.concat(validate_certification_type(record))
    errors.concat(validate_integer_fields(record))

    errors.empty? ? ValidationResult.success : ValidationResult.failure(errors)
  end

  private

  # Validate all required fields are present and not blank
  # Uses blank? check (not key presence) since CSV always creates keys for all columns
  def validate_required_fields(record)
    missing = REQUIRED_FIELDS.select { |field| record[field].blank? }
    return [] if missing.empty?

    [
      {
        code: BatchUploadErrors::Validation::MISSING_FIELDS,
        message: "Missing required fields: #{missing.join(', ')}"
      }
    ]
  end

  # Validate date field formats and parseability
  def validate_date_formats(record)
    errors = []

    DATE_FIELDS.each do |field|
      error = validate_date_field(record, field)
      errors << error if error
    end

    OPTIONAL_DATE_FIELDS.each do |field|
      next if record[field].blank?

      error = validate_date_field(record, field)
      errors << error if error
    end

    errors
  end

  # Validate a single date field, returns error hash or nil
  # Enforces YYYY-MM-DD format and uses Strata's date casting for validity (e.g., rejects month 13, day 32)
  def validate_date_field(record, field)
    value = record[field]
    return nil if value.nil?

    return nil if value.match?(DATE_FORMAT) && Strata::USDate.cast(value).present?

    {
      code: BatchUploadErrors::Validation::INVALID_DATE,
      message: "Field '#{field}' has invalid date '#{value}'. Expected valid date in YYYY-MM-DD format (e.g., 2025-01-15)"
    }
  end

  # Validate email format
  def validate_email_format(record)
    email = record["member_email"]
    return [] if email.blank?
    return [] if email.match?(EMAIL_REGEX)

    [
      {
        code: BatchUploadErrors::Validation::INVALID_EMAIL,
        message: "Field 'member_email' has invalid email format '#{email}'. Expected valid email (e.g., user@example.com)"
      }
    ]
  end

  # Validate certification type is in allowed values
  def validate_certification_type(record)
    cert_type = record["certification_type"]
    return [] if cert_type.blank?
    return [] if CERTIFICATION_TYPES.include?(cert_type)

    [
      {
        code: BatchUploadErrors::Validation::INVALID_TYPE,
        message: "Field 'certification_type' has invalid value '#{cert_type}'. " \
                 "Allowed values: #{CERTIFICATION_TYPES.join(', ')}"
      }
    ]
  end

  # Validate integer fields (when present)
  def validate_integer_fields(record)
    errors = []

    INTEGER_FIELDS.each do |field|
      value = record[field]
      next if value.blank?

      unless value.to_s.match?(INTEGER_FORMAT)
        errors << {
          code: BatchUploadErrors::Validation::INVALID_INTEGER,
          message: "Field '#{field}' has invalid integer value '#{value}'. Expected positive integer (e.g., 30)"
        }
      end
    end

    errors
  end
end
