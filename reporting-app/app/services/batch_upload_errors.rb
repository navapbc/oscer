# frozen_string_literal: true

# Centralized error codes for batch upload processing
# Categories map to retry strategies per docs/architecture/batch-upload/batch-upload.md
#
# Error code format: [CATEGORY]_[NUMBER]
# - VAL_* - Validation errors (log and skip, no retry)
# - DUP_* - Duplicate errors (log and skip, no retry)
# - DB_* - Database errors (retry chunk 3x)
# - STG_* - Storage errors (retry job 5x)
# - UNK_* - Unknown errors (fail batch, manual)
module BatchUploadErrors
  # Validation errors - data format/type issues
  module Validation
    MISSING_FIELDS = "VAL_001"        # Required field(s) missing
    INVALID_DATE = "VAL_002"          # Date format invalid or unparseable
    INVALID_EMAIL = "VAL_003"         # Email format invalid
    INVALID_TYPE = "VAL_004"          # Enum field not in allowed values
    INVALID_INTEGER = "VAL_005"       # Integer field contains non-numeric
  end

  # Duplicate errors - record already exists
  module Duplicate
    EXISTING_CERTIFICATION = "DUP_001"  # Certification already exists
  end

  # Database errors - persistence failures
  module Database
    SAVE_FAILED = "DB_001"            # ActiveRecord save failed
  end

  # Storage errors - cloud storage operations
  module Storage
    READ_FAILED = "STG_001"           # Storage read/stream failed
  end

  # Unknown errors - unexpected exceptions
  module Unknown
    UNEXPECTED = "UNK_001"            # Catch-all for StandardError
  end

  # Retrieve all error codes for testing
  def self.all_codes
    constants.flat_map do |category|
      const_get(category).constants.map do |code|
        const_get(category).const_get(code)
      end
    end
  end
end
