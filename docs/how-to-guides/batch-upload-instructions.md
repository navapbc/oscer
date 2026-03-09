# Batch Upload Instruction Guide

## Overview

The Batch Upload feature allows staff members and state system integrators to upload and process multiple certifications at once using CSV files. Files can be uploaded through the **staff web UI** or programmatically via the **API**.

Processing begins automatically when a file is uploaded — there is no manual "process" step. The system splits large files into chunks of 1,000 records and processes them in parallel, providing live progress tracking on the dashboard.

## Prerequisites

- **Staff UI**: Admin access to the Medicaid staff portal
- **API**: An HMAC API key pair (contact your system administrator)
- A properly formatted **CSV file** (see [Data Schema](#data-schema) below)

---

## Data Schema

### Required Fields

| Field | Description | Format |
|-------|-------------|--------|
| `member_id` | Unique member identifier | Text (e.g., M12345) |
| `case_number` | Medicaid case number (must be unique) | Text (e.g., C-001) |
| `member_email` | Member's email address | Valid email |
| `certification_date` | Date of certification | YYYY-MM-DD |
| `certification_type` | Type of certification | `new_application` or `recertification` |

### Optional Fields

| Field | Description | Format |
|-------|-------------|--------|
| `first_name` | Member's first name | Text |
| `middle_name` | Member's middle name | Text |
| `last_name` | Member's last name | Text |
| `lookback_period` | Months to look back | Positive integer |
| `number_of_months_to_certify` | Months to certify | Positive integer |
| `due_period_days` | Days until due | Positive integer |
| `address` | Street address | Text |
| `county` | County name | Text |
| `zip_code` | ZIP code | Text (e.g., 12345) |
| `date_of_birth` | Date of birth | YYYY-MM-DD |
| `pregnancy_status` | Pregnancy status | `yes` or `no` |
| `race_ethnicity` | Race/ethnicity | Text |
| `work_hours` | Current work hours | Positive integer |
| `other_income_sources` | Other income description | Text |

### Template and Example CSV

- [Download CSV template](/certification_batch_upload_template.csv) — also available on the upload page
- [Download sample CSV with test data](/docs/assets/test_data.csv)

> **Note:** If you want to receive email notifications, change the emails in the sample CSV to real email addresses.

```csv
member_id,case_number,member_email,first_name,last_name,certification_date,certification_type,date_of_birth,pregnancy_status,race_ethnicity
M12345,C-001,john.doe@example.com,John,Doe,2025-01-15,new_application,1990-05-15,no,white
M12346,C-002,jane.smith@example.com,Jane,Smith,2025-01-15,recertification,1985-03-20,yes,black
```

---

## Staff UI Upload

### Step 1: Prepare Your CSV File

1. Create a CSV file with the required columns (see [Data Schema](#data-schema) above), or [download the template](/certification_batch_upload_template.csv)
2. Ensure **case numbers are unique** — duplicate case numbers will be flagged as errors
3. Save the file in `.csv` format

#### Testing Exemptions

To test different exemption scenarios, use the following fields:

| Exemption Type | How to Test |
|----------------|-------------|
| **Age exemption** | Set `date_of_birth` so member is under 19 or over 64 |
| **Tribal exemption** | Set `race_ethnicity` to `american_indian_or_alaska_native` |
| **Pregnancy exemption** | Set `pregnancy_status` to `yes` |

**Note:** For Medicaid age eligibility, members must be between 19 and 64 years old.

### Step 2: Upload Your CSV File

1. Navigate to **Batch Uploads** in the header navigation (or go directly to `/staff/certification_batch_uploads`)
2. Click **"Upload New File"**
3. On the upload page, you can expand the **CSV Format Requirements** section to review required and optional fields
4. Select your CSV file using the file picker
5. Click **"Upload"**
6. You'll be redirected to the Batch Uploads list with a success message

<!-- TODO: Update screenshots to reflect the v2 UI -->

Processing begins automatically in the background. There is no separate "process" step.

### Step 3: Monitor Progress

The Batch Uploads list page auto-refreshes every 5 seconds while any batch is processing. You'll see:

- **Status**: Pending, Processing, Completed, or Failed
- **Progress**: Number of rows processed out of total (e.g., "500 / 1,000")

Once processing completes, the status updates to **Completed** and action links become available.

### Step 4: View Batch Details

1. Click on a **filename** in the Batch Uploads list to see the batch detail page
2. The detail page shows:
   - **Filename** and **uploaded by** (uploader's email)
   - **Uploaded at** and **processed at** timestamps
   - **Status** with a color-coded tag
   - **Total rows** in the CSV
   - A status alert showing:
     - Success count and error count for completed batches
     - Progress for in-progress batches
     - Error message for failed batches
3. If the batch completed with errors, an **error table** shows up to 100 errors with:
   - **Row number** (corresponding to the CSV line)
   - **Error code** (e.g., VAL_001, DUP_001)
   - **Error message** (human-readable explanation)
   - **Row data** (the original CSV record)

### Step 5: Download Error Report

If a completed batch has errors, you can download a full error report:

1. On the batch detail page, click **"Download Errors"**
2. A CSV file downloads with columns: Row, Error Code, Error Message, Row Data
3. Use this to fix the errors in your source CSV and re-upload

### Step 6: View Member Results

1. From the Batch Uploads list, click **"View Results"** for a completed batch
2. The results page shows all certifications created from the batch
3. Filter results using the status buttons:
   - All
   - Compliant
   - Exempt
   - Member action required
   - Pending review
4. Click on a member name or case number to view individual details

---

## API Upload

The API allows state systems to upload batch files programmatically using HMAC-authenticated requests.

### Authentication

All API requests must include an HMAC signature. The signature is computed over the request body using your API secret key. See your system administrator for credentials.

### Step 1: Upload the File

Upload the CSV file to get a signed blob ID:

```bash
# Upload the file via ActiveStorage direct upload
curl -X POST "${BASE_URL}/rails/active_storage/direct_uploads" \
  -H "Content-Type: application/json" \
  -d '{
    "blob": {
      "filename": "certifications.csv",
      "content_type": "text/csv",
      "byte_size": 1024,
      "checksum": "<base64-md5-checksum>"
    }
  }'
```

The response includes a `direct_upload` URL and a `signed_id`. Upload the file content to the `direct_upload` URL, then use the `signed_id` in the next step.

```bash
# Upload file content to the direct upload URL
curl -X PUT "<direct_upload_url>" \
  -H "Content-Type: text/csv" \
  --data-binary @certifications.csv
```

### Step 2: Create the Batch Upload

```bash
curl -X POST "${BASE_URL}/api/certification_batch_uploads" \
  -H "Content-Type: application/json" \
  -H "Authorization: <hmac-signature>" \
  -d '{
    "certification_batch_upload": {
      "signed_blob_id": "<signed_id_from_step_1>"
    }
  }'
```

**Response** (201 Created):
```json
{
  "id": 42,
  "status": "pending",
  "filename": "certifications.csv",
  "source_type": "api",
  "num_rows": null,
  "num_rows_processed": 0,
  "num_rows_succeeded": 0,
  "num_rows_errored": 0,
  "created_at": "2026-03-09T12:00:00Z",
  "processed_at": null
}
```

Processing begins automatically after creation.

### Step 3: Poll for Status

```bash
curl -X GET "${BASE_URL}/api/certification_batch_uploads/42" \
  -H "Authorization: <hmac-signature>"
```

**Response** (200 OK — processing):
```json
{
  "id": 42,
  "status": "processing",
  "filename": "certifications.csv",
  "source_type": "api",
  "num_rows": 5000,
  "num_rows_processed": 2000,
  "num_rows_succeeded": 1950,
  "num_rows_errored": 50,
  "created_at": "2026-03-09T12:00:00Z",
  "processed_at": null
}
```

**Response** (200 OK — completed):
```json
{
  "id": 42,
  "status": "completed",
  "filename": "certifications.csv",
  "source_type": "api",
  "num_rows": 5000,
  "num_rows_processed": 5000,
  "num_rows_succeeded": 4900,
  "num_rows_errored": 100,
  "created_at": "2026-03-09T12:00:00Z",
  "processed_at": "2026-03-09T12:05:00Z"
}
```

Poll the status endpoint until `status` is `completed` or `failed`. A recommended poll interval is 5–10 seconds.

### API Error Codes

| HTTP Status | Meaning |
|-------------|---------|
| 201 | Batch created successfully |
| 401 | Invalid or missing HMAC signature |
| 404 | Batch not found, or not an API-sourced upload |
| 422 | Invalid request (e.g., missing or invalid `signed_blob_id`) |

> **Note:** API clients can only view batches they created (source_type: `api`). Staff-uploaded batches are not visible via the API.

---

## Error Codes Reference

When records fail validation, each error is tagged with a code for programmatic handling:

| Code | Description |
|------|-------------|
| `VAL_001` | Missing required field(s) |
| `VAL_002` | Invalid date format (expected YYYY-MM-DD) |
| `VAL_003` | Invalid email format |
| `VAL_004` | Invalid certification type (must be `new_application` or `recertification`) |
| `VAL_005` | Invalid integer value (must be a positive integer) |
| `DUP_001` | Duplicate — certification already exists for this member/case |
| `DB_001` | Database save failed |
| `STG_001` | Storage read failed |
| `UNK_001` | Unexpected error |

---

## Troubleshooting

| Issue | Potential Cause | Solution |
|-------|-----------------|----------|
| Upload fails immediately | Invalid file format | Ensure the file is saved as `.csv` with UTF-8 encoding |
| Row marked with `VAL_001` | Missing required field | Check that all required fields have values for that row |
| Row marked with `DUP_001` | Member/case already exists | This is expected — duplicates are skipped to prevent double-processing |
| Batch stuck in "Processing" | Large file still being processed | The dashboard auto-refreshes every 5 seconds. Large files (thousands of rows) may take a few minutes as chunks process in parallel |
| Batch shows "Failed" | System error during processing | Check the error message on the batch detail page. If it's a transient error, re-upload the file |
| API returns 401 | Invalid HMAC signature | Verify your API key and signature computation |
| API returns 404 on status check | Wrong batch ID, or batch was uploaded via UI | API clients can only view API-sourced batches |

---

## Error Recovery

- **Partial failures are normal** — successfully processed rows are saved even if other rows fail
- Download the error CSV to see exactly which rows failed and why
- Fix the errors in your source file and re-upload — duplicates are automatically skipped (safe to reprocess)
- For system-level failures (status: "Failed"), the entire batch can be re-uploaded
