# Batch Upload Error Codes

This document describes the error code system for batch upload processing.

## Error Code Categories

Error codes follow the pattern `[CATEGORY]_[NUMBER]`:

| Category | Action       | Retry  | Purpose |
|----------|--------------|--------|---------|
| VAL_*    | Log and skip | No     | Data validation errors (format, type, range) |
| DUP_*    | Log and skip | No     | Duplicate records |
| DB_*     | Retry chunk  | 3x     | Database operation failures |
| STG_*    | Retry job    | 5x     | Storage operation failures |
| UNK_*    | Fail batch   | Manual | Unexpected errors requiring investigation |

## All Error Codes

### Validation Errors (VAL_*)

- **VAL_001** - Missing required fields (`member_id`, `case_number`, `member_email`, `certification_date`, `certification_type`)
- **VAL_002** - Invalid date format (expected YYYY-MM-DD, e.g., "2025-03-15")
- **VAL_003** - Invalid email format (must match RFC 5322)
- **VAL_004** - Invalid enum value (e.g., `certification_type` must be "new_application" or "recertification")
- **VAL_005** - Invalid integer field (contains letters or special characters)

### Duplicate Errors (DUP_*)

- **DUP_001** - Certification already exists (same `member_id`, `case_number`, `certification_date`)

### Database Errors (DB_*)

- **DB_001** - Database save failed (ActiveRecord validation failure)

### Storage Errors (STG_*)

- **STG_001** - Storage read/stream failed (not currently used in record processor)

### Unknown Errors (UNK_*)

- **UNK_001** - Unexpected error (catch-all for StandardError; includes backtrace in logs)

## Usage in Code

```ruby
# Use constants instead of strings
raise ValidationError.new(
  BatchUploadErrors::Validation::MISSING_FIELDS,
  "Missing required fields: member_id, case_number"
)

# In tests
expect(error.code).to eq(BatchUploadErrors::Validation::MISSING_FIELDS)
```

## Adding New Error Codes

1. Add constant to `BatchUploadErrors` module in appropriate category
2. Update this documentation with description
3. Add validation/handling logic
4. Add test cases for the new error

## Architecture Reference

See `docs/architecture/batch-upload/batch-upload.md` for error handling strategy and retry logic.
