# Configuring DocAI

This guide covers setting up the DocAI document extraction service for local development and deployed environments. DocAI extracts structured data (earnings, tax information, identity) from income verification documents (paystubs, W-2s, tax returns, driver's licenses) for rapid, accurate processing in OSCER workflows.

## Prerequisites

- DocAI API service running (AWS-hosted in production)

## Environment Variables

DocAI is configured entirely via environment variables:

```bash
# REQUIRED: URL of the DocAI API service
DOC_AI_API_HOST=http://doc-ai-service.example.com

# Optional: API request timeout (seconds)
DOC_AI_TIMEOUT_SECONDS=60

# Optional: confidence threshold for task queue prioritization
# Activities with average confidence < this are flagged for higher caseworker priority
DOC_AI_LOW_CONFIDENCE_THRESHOLD=0.7

# Optional: enable the feature flag
FEATURE_DOC_AI=true
```

### Variable Details

| Variable | Purpose | Default | Notes |
|----------|---------|---------|-------|
| `DOC_AI_API_HOST` | DocAI API endpoint URL | Required (no default) | Production: AWS-hosted URL. |
| `DOC_AI_TIMEOUT_SECONDS` | Timeout for API calls (both submission and polling) | `60` | Increase if network is slow or processing takes longer. |
| `DOC_AI_LOW_CONFIDENCE_THRESHOLD` | Confidence floor for task prioritization | `0.7` (70%) | Range: 0.0–1.0. Lower threshold = more tasks flagged as high-priority. |
| `FEATURE_DOC_AI` | Enable/disable DocAI feature | `false` (disabled) | Set `true` to activate document staging flow for members. |

### Using the Paystub Template Generator

OSCER includes an interactive paystub builder for testing. This generates realistic PDF paystubs that you can upload to DocAI.

1. **Open the template**: Open `docs/how-to-guides/example_upload_document_builders/paystub_template.html` in your browser
   - The template has a form panel on the left and a live preview on the right
   - Default values are pre-filled: "Crestwood Digital Solutions LLC", employee "Jane A. Sample", pay period Feb 2026, etc.

2. **Customize** (optional):
   - Edit organization name, address, EIN
   - Set pay period and pay date (match the reporting month you're testing)
   - Adjust employee name, ID, department, hours, hourly rate
   - Add/remove deductions as needed
   - Live preview updates as you type

3. **Generate PDF**:
   - Click **"Print / Save as PDF"**
   - Browser's print dialog opens
   - Select "Save as PDF" (or print to PDF using your OS print driver)
   - Save the file (e.g., `test-paystub.pdf`)

4. **Upload and test**:
   - Navigate to the Activity report flow in OSCER (via the member dashboard)
   - Ensure the DocAI feature flag is enabled (`FEATURE_DOC_AI=true`)
   - Follow the prompts to upload your document
   - Wait for processing (the interface will show progress as DocAI analyzes the file)
   - Verify that the extracted fields (such as pay period, gross pay, etc.) match the data you entered in the template

### Example Test Scenarios

**Scenario 1: Different pay period**
- Set pay period to match a specific reporting month (e.g., Jan 2026 for certification period Jan–Mar 2026)
- DocAI extracts month from `payperiodstartdate`
- Activity creation uses this extracted month to determine which reporting period it belongs to

## Verifying the Connection

After uploading a document, you can check the extraction result:

### In the Rails Console

```ruby
# Find the most recent staged document
staged = StagedDocument.order(created_at: :desc).first

# Check processing status
staged.status                # => "pending", "validated", "rejected", or "failed"

# View extracted fields (if validated)
staged.extracted_fields      # => { "currentgrosspay" => { "confidence" => 0.93, "value" => 1627.74 }, ... }

# Check average confidence
staged.average_confidence    # => 0.87 (float, 0.0–1.0)

# Identify matched document class
staged.doc_ai_matched_class  # => "Payslip"
```

### Understanding Extraction Results

**Successful (status: `validated`)**:
- `extracted_fields` contains structured data (earnings, deductions, employee info, etc.)
- Confidence scores range 0.0–1.0 per field
- `average_confidence` is the mean of all field confidences
- Document class is recognized (currently only `Payslip` is fully supported)

**Rejected (status: `rejected`)**:
- DocAI could not recognize the document type
- `extracted_fields` is empty
- Common causes: document is not a paystub, image quality too low, unsupported format
- Member can choose to proceed anyway (`AI_REJECTED_MEMBER_OVERRIDE` attribution) or resubmit

**Failed (status: `failed`)**:
- API error, network error, or timeout
- `extracted_fields` may be empty
- Check Rails logs for the specific error
- Member can retry submission

### Checking Background Job Status

DocAI uses a background job (`FetchDocAiResultsJob`) to poll for results:

Job details:
- **Initial delay**: 1 minute (gives DocAI time to start processing)
- **Retry interval**: 30 seconds
- **Max attempts**: 5
- **Total window**: ~3 minutes from submission to failure or completion
- On exhaustion: docs marked `failed`; manual resubmission required

## Troubleshooting

### New document type not recognized
- Currently, only **Payslip** is registered in `SUPPORTED_RESULT_CLASSES`
- To add support: register the new `DocAiResult::ClassName` in `DocumentStagingService`
- Other document types DocAI can ingest include W2s, Driver Licenses, Bank Statements, Receipts.
- Issues may be opened up to request document types in addition to Payslip.
