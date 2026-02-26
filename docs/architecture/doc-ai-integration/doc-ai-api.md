# DocAI Integration

## Problem

OSCER members are required to submit income verification documents (e.g., pay stubs) as part of their certification and exemption workflows. Staff currently review these documents manually, which is time-consuming, error-prone, and creates processing delays.

Integrating with the NavaPBC DocAI service enables:

1. **Realtime document validation** — When a member uploads a pay stub, OSCER confirms in realtime — within the upload request — that the document is a recognized Payslip before accepting it, providing immediate feedback and preventing invalid submissions from entering the review queue
2. **Automated data extraction** — Structured fields (gross pay, pay period dates, YTD totals, employer details) are extracted from uploaded documents without staff intervention
3. **Faster determinations** — Pre-populated form data reduces member burden and accelerates staff review
4. **Consistent parsing** — Machine-extracted fields apply uniform rules regardless of document formatting variation

## Approach

A thin adapter + service + value object pattern integrates DocAI into existing OSCER workflows without coupling business logic to the external API:

- **`DocumentStagingController`** — Accepts one or more file uploads from the browser via a standard HTML form POST, validates content type via server-side magic-byte detection (Marcel — PDF or JPG/JPEG) and size (≤30 MB) per file, builds a `StagedDocument` per file with its attachment and saves atomically, delegates to `DocAiService` **concurrently** on a dedicated `Concurrent::FixedThreadPool` (all files are analyzed in parallel via `Concurrent::Future`, so total wait time ≈ one DocAI call regardless of file count), updates each record's status and extracted fields, and renders a template containing prefilled fields and hidden `staged_document_signed_ids[]` fields for each validated document
- **`StagedDocument`** — ActiveRecord model that owns the uploaded file (via `has_one_attached :file`) and tracks DocAI validation state, the full raw API response (including confidence scores), and the `job_id`. Retained permanently as an audit record.`belongs_to :stageable, polymorphic: true` links the document to whatever parent model consumes it (e.g., `Activity`, `Exemption`)
- **`DocAiAdapter`** — Handles the HTTP boundary: POSTs a file to DocAI via multipart upload and returns the raw response body
- **`DocAiService`** — Orchestrates the call: invokes the adapter, maps the response to a typed value object, logs the DocAI `job_id`, and raises `ProcessingError` for failed jobs
- **`DocAiResult` / `DocAiResult::Payslip` / `DocAiResult::W2`** — Immutable value objects representing the API response; the base class holds the response envelope and a factory method; subclasses expose typed, snake_case accessors per document class

```mermaid
flowchart LR
    Browser -->|"HTML form POST\n(multipart/form-data, files[])"| Controller[DocumentStagingController]
    Controller -->|"Marcel magic-byte validation\nPDF or JPG/JPEG ≤30 MB (per file)"| Controller
    Controller -->|"Concurrent::Future per file\n(dedicated FixedThreadPool)"| Controller
    Controller -->|"StagedDocument.new(pending)\n+ file.attach + save!"| DB[(PostgreSQL)]
    Controller -->|"file.attach"| AS[ActiveStorage / S3]
    Controller -->|"staged_document.file"| DocAiService
    DocAiService -->|file| DocAiAdapter
    DocAiAdapter -->|"POST /v1/documents?wait=true\n(60s timeout)"| DocAI[DocAI API]
    DocAI -->|JSON response| DocAiAdapter
    DocAiAdapter -->|response body| DocAiService
    DocAiService -->|DocAiResult| Controller
    Controller -->|"update!(validated, fields, job_id)"| DB
    Controller -->|"Render HTML template\n(prefilled fields + signed_id hidden fields)"| Browser
```

**Processing model**: The `wait=true` parameter causes DocAI to block until processing completes, returning a single synchronous response within the upload request. No polling or webhook handling is required. If DocAI does not respond within 60 seconds, Faraday raises a `TimeoutError` and the service returns an error to the controller. When multiple files are uploaded, all DocAI calls run concurrently via `Concurrent::Future` on a dedicated `FixedThreadPool` — total wall-clock time is approximately equal to one DocAI call (~38 seconds) rather than scaling linearly with file count.

---

## User Interaction Flow

> End-to-end sequence from file selection to form prefill

```mermaid
sequenceDiagram
    actor Member
    participant Browser
    participant Controller as DocumentStagingController
    participant DB as StagedDocument (DB)
    participant DocAI as DocAiService

    Member->>Browser: Selects one or more files via file input
    Browser->>Controller: POST /document_staging (multipart/form-data, files[])

    Controller->>Controller: Validate content type (Marcel magic-byte) + size for each file (collect errors for invalid files)

    par Concurrent — one Future per valid file (dedicated FixedThreadPool)
        Controller->>DB: StagedDocument.new(pending) + file.attach + save!
        Controller->>DocAI: analyze(file: staged_document.file)
        alt DocAI returns recognised income document (Payslip or W2)
            Controller->>DB: update!(status: :validated, extracted_fields, job_id)
        else Unrecognised document type
            Controller->>DB: update!(status: :rejected)
        else DocAI unavailable
            Controller->>DB: update!(status: :failed)
        end
    end

    Controller->>Controller: Collect all Future results + validation errors
    Controller->>Browser: Render template (prefilled fields + signed_id hidden fields per validated doc, errors for others)
    Browser->>Member: Shows prefilled form / validation errors
```

| Step | Notes |
|------|-------|
| File selection | The file input includes the `multiple` attribute; the member may select one or more files at once |
| Concurrent processing | Each valid file is dispatched to its own `Concurrent::Future`; all DocAI calls run in parallel so total wall-clock time ≈ one call (~38s) regardless of file count |
| StagedDocument creation | A `StagedDocument` is built with `status: :pending`, the file is attached, and `save!` commits both atomically — if the attach fails (e.g., S3 error), no orphaned record is persisted. Each Future checks out its own DB connection via `connection_pool.with_connection` |
| Income document check | `SUPPORTED_RESULT_CLASSES.any? { \|klass\| result.is_a?(klass) }` — both Payslip and W2 are accepted; any other matched class is rejected at this step |
| Status update | All outcomes update the `StagedDocument` status (`validated`, `rejected`, or `failed`) — the record is retained permanently as an audit trail |
| UI prefill | Prefilled fields and `staged_document_signed_ids` hidden inputs are embedded in the rendered HTML template; the full DocAI response — including per-field confidence scores — is persisted in the `extracted_fields` JSONB column for staff review |

---

## Activity Attachment Flow

> How validated `StagedDocument`(s) get attached to an `Activity` record and how the manual upload step is bypassed

After `DocumentStagingController` validates each file with DocAI, each `StagedDocument` record holds the file via ActiveStorage and has `status: :validated`. This section describes how the staged documents are connected to an `Activity` record.

### 1. `DocumentStagingController` renders hidden `staged_document_signed_ids` fields

After processing all uploaded files, the controller renders a template. For each validated document, the template embeds a hidden input containing the document's signed ID — an HMAC-signed, time-limited token (1 hour expiry) generated by `ActiveRecord::SignedId` that the browser can pass back without exposing the raw record UUID. Multiple validated documents produce multiple hidden fields:

```html
<input type="hidden" name="activity[staged_document_signed_ids][]" value="signed_id_1">
<input type="hidden" name="activity[staged_document_signed_ids][]" value="signed_id_2">
```

The signed ID cannot be forged or replayed after expiry. The template also renders prefilled activity form fields extracted from each validated document.

### 2. `ActivitiesController#create` attaches blobs and skips the upload step

When `params[:activity][:staged_document_signed_ids]` is present, the controller iterates over the array, resolves each `StagedDocument` via `find_signed`, attaches its blob directly to the activity (no S3 copy is made — the same blob is shared), marks each staged document as consumed, and redirects to the next step, bypassing the `documents` upload page. This logic runs **after** the `@activity` has been persisted (via the parent form save):

```ruby
# After @activity is persisted:
if (signed_ids = activity_params[:staged_document_signed_ids]).present?
  signed_ids.each do |sid|
    staged = StagedDocument.find_signed(sid)
    next unless staged&.validated?

    @activity.supporting_documents.attach(staged.file.blob)
    staged.update!(stageable: @activity)
  end
  redirect_to activity_report_application_form_path(@activity_report_application_form),
              notice: t(".created_with_document")
else
  redirect_to documents_activity_report_application_form_activity_path(
                @activity_report_application_form, @activity)
end
```

`staged_document_signed_ids` (array) must be added to the permitted params list in `ActivitiesController`:

```ruby
def activity_params
  params.require(:activity).permit(
    :month, :name, :hours, :income, :activity_type, :category,
    staged_document_signed_ids: []
  )
end
```

When a signed ID is expired or the record is not validated, that entry is skipped gracefully — other valid documents in the same submission are still attached. The polymorphic `stageable` association is set to the `@activity`, linking the `StagedDocument` to whatever parent model consumes it.

When no signed IDs are present — because DocAI was unavailable, the member has not yet uploaded files, or all uploads failed — the existing redirect to the `documents` upload page is preserved unchanged. Degradation is graceful; the manual upload path remains fully functional.

### End-to-End Sequence Diagram

#### Happy path (DocAI available, files are valid income documents)

```mermaid
sequenceDiagram
    actor Member
    participant Browser
    participant Staging as DocumentStagingController
    participant DB as StagedDocument (DB)
    participant Activities as ActivitiesController

    Member->>Browser: Selects files via file input
    Browser->>Staging: POST /document_staging (multipart/form-data, files[])
    Staging->>Staging: Validate PDF/JPG via Marcel magic-byte + size (per file)
    par Concurrent Futures on dedicated FixedThreadPool (one per valid file)
        Staging->>DB: StagedDocument.new(pending) + file.attach + save! → DocAI → update!(validated, fields, job_id)
    end
    Staging->>Staging: Collect all Future results
    Staging->>Browser: Render template (prefilled fields + hidden staged_document_signed_ids[] inputs)

    Member->>Browser: Fills remaining fields, submits activity form
    Browser->>Activities: POST /activity_report_application_forms/:id/activities
    loop For each signed_id
        Activities->>DB: StagedDocument.find_signed(signed_id)
        Activities->>Activities: staged.validated? → true
        Activities->>Activities: @activity.supporting_documents.attach(staged.file.blob)
        Activities->>DB: staged.update!(stageable: @activity)
    end
    Activities->>Browser: Redirect to next step (skip documents upload page)
```

#### Fallback path (DocAI unavailable)

```mermaid
sequenceDiagram
    actor Member
    participant Browser
    participant Staging as DocumentStagingController
    participant DB as StagedDocument (DB)
    participant Activities as ActivitiesController
    participant Upload as Documents Upload Page

    Member->>Browser: Selects files via file input
    Browser->>Staging: POST /document_staging (multipart/form-data, files[])
    Staging->>DB: StagedDocument.new(pending) + file.attach + save! → update!(failed) [per file]
    Staging->>Browser: Render template with errors (no validated documents)
    Browser->>Member: Error — manual entry fallback

    Member->>Browser: Fills fields manually, submits activity form
    Browser->>Activities: POST /activity_report_application_forms/:id/activities
    Activities->>Activities: No staged_document_signed_ids in params
    Activities->>Upload: Redirect to documents_activity_report_application_form_activity_path
    Upload->>Member: Existing manual upload flow (unchanged)
```

### Design Decisions

**`signed_id` as the hand-off token** — A signed ID (`ActiveRecord::SignedId`) is tamper-proof and time-limited (1 hour). A raw UUID would require an explicit authorization check to prevent IDOR (member A passing member B's staged_document UUID). The `signed_id` approach eliminates this attack surface without a DB membership query. `StagedDocument.find_signed` resolves directly to the record with one method call.

**Blob sharing, not blob copying** — `staged.file.blob` returns the existing `ActiveStorage::Blob`. Attaching it to `Activity.supporting_documents` creates a new `active_storage_attachments` row pointing at the same S3 object — no storage copy is made. Both the `StagedDocument` and the `Activity` reference the same physical file.

**`StagedDocument` retained as audit record** — Unlike a staging copy that would be deleted after use, `StagedDocument` rows are retained permanently. The polymorphic `stageable` association is set when the blob is transferred to a parent model, marking the record as consumed. Since `StagedDocument` records are never purged, the blob is safe from premature deletion even after it is attached to the parent.

**Graceful degradation preserved** — When `staged_document_signed_ids` is absent, the existing `documents` upload page is still reachable, maintaining the current flow as a fallback with no changes to `ActivityReportApplicationFormsController`.

**No changes to `ActivityReportApplicationFormsController`** — The flow change lives entirely in `ActivitiesController#create`. The multi-step form orchestration layer is unaffected.

**Server-rendered prefill** — `DocumentStagingController` renders a template rather than returning JSON. Prefilled fields and signed IDs are embedded in the HTML, eliminating the need for a client-side JS upload controller.

**Multiple signed IDs as array** — Each validated file produces its own `StagedDocument` and signed ID. The activity form accepts `staged_document_signed_ids[]` (array). `ActivitiesController#create` iterates, skipping expired or non-validated entries.

---

## C4 Context Diagram

> Level 1: External actors and systems

```mermaid
flowchart TB
    Member[Member] -->|"uploads income document"| OSCER[OSCER Application]
    Staff[Staff User] -->|"reviews extracted data"| OSCER
    OSCER -->|"POST file for analysis"| DocAI[DocAI Platform\napp-docai.platform-test-dev.navateam.com]
    DocAI -->|"structured fields + confidence scores"| OSCER
```

| Actor/System   | Interaction                                                                    |
|----------------|--------------------------------------------------------------------------------|
| Member         | Uploads income document (pay stub) through OSCER UI                           |
| Staff User     | Reviews pre-populated fields extracted from member documents                   |
| OSCER          | Sends uploaded file to DocAI; receives structured field data                   |
| DocAI Platform | Analyzes document; returns matched document class and extracted field values   |

---

## C4 Container Diagram

> Level 2: Deployable units

```mermaid
flowchart TB
    Member[Member] -->|"HTTPS"| WebApp[Web Application - Rails]
    WebApp --> DB[(PostgreSQL)]
    WebApp -->|"ActiveStorage: attach / read"| S3[(S3 via ActiveStorage)]
    WebApp -->|"POST multipart file\n(synchronous, ≤60s)"| DocAI[DocAI External Service]
    DocAI -->|"JSON response"| WebApp
```

| Container              | Technology     | Responsibilities                                                                                  |
|------------------------|----------------|---------------------------------------------------------------------------------------------------|
| Web Application        | Rails 7.2      | HTTP handling, file validation, `StagedDocument` lifecycle, DocAI delegation, UI prefill          |
| PostgreSQL             | PostgreSQL 14+ | Persistent storage including `staged_documents` table                                             |
| S3 (via ActiveStorage) | AWS S3         | Durable file storage; bucket configuration managed by ActiveStorage (no custom S3 operations)     |
| DocAI External Service | NavaPBC DocAI  | Document classification and field extraction                                                      |

---

## C4 Component Diagram

> Level 3: Internal components

```mermaid
flowchart TB
    subgraph web [Web Application]
        Controller[DocumentStagingController]
        Validator[File Validator\nMarcel magic-byte · PDF/JPG · ≤30 MB]
    end

    subgraph domain [Domain Layer]
        StagedDoc[StagedDocument\nstatus · file · extracted_fields]
        AS[ActiveStorage / S3]
    end

    subgraph integration [Integration Layer]
        Service[DocAiService]
        Adapter[DocAiAdapter]
    end

    subgraph results [Value Objects]
        Result[DocAiResult\nbase value object]
        Payslip[DocAiResult::Payslip\nsubclass]
        W2[DocAiResult::W2\nsubclass]
    end

    Controller --> Validator
    Controller -->|"new + file.attach + save!"| StagedDoc
    StagedDoc --> AS
    Controller -->|"analyze(file: staged_document.file)"| Service
    Service -->|"analyze_document(file:)"| Adapter
    Adapter -->|"POST /v1/documents?wait=true\n(60s timeout)"| DocAI[DocAI API]
    DocAI -->|"JSON body"| Adapter
    Adapter -->|"response body hash"| Service
    Service -->|"DocAiResult.from_response"| Result
    Result -->|"DocAiResult::Payslip"| Payslip
    Result -->|"DocAiResult::W2"| W2
    Service -->|"DocAiResult"| Controller
    Controller -->|"update!(validated, fields, job_id)"| StagedDoc
```

### Key Components

| Component                    | Responsibility                                                                                                              |
|------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `DocumentStagingController`  | Validates uploads via Marcel magic-byte detection (PDF or JPG/JPEG, ≤30 MB per file), processes all valid files concurrently on a dedicated `FixedThreadPool` via `Concurrent::Future`, builds + attaches + saves `StagedDocument` atomically per file, calls `DocAiService`, updates status/fields, renders template with prefilled fields and hidden signed_id inputs |
| File Validator               | Enforces PDF or JPG/JPEG content type via server-side magic-byte detection (Marcel), ≤30 MB size limit, and ≤2 file count before any DB or DocAI operations |
| `StagedDocument`             | ActiveRecord model: owns uploaded file via `has_one_attached :file`; tracks DocAI validation status, full raw API response (with confidence scores) in `extracted_fields` JSONB, `job_id`, `user_id`, and polymorphic `stageable` parent |
| `DocAiAdapter`               | POSTs file via Faraday multipart; maps HTTP errors to typed exceptions                                                      |
| `DocAiService`               | Invokes adapter; builds result value object; logs `job_id`; raises `ProcessingError` on failure                            |
| `DocAiResult`                | Base value object: response envelope, `FieldValue` accessor, self-registration factory                                      |
| `DocAiResult::FieldValue`    | Immutable struct wrapping `value` + `confidence`; exposes `low_confidence?` predicate                                       |
| `DocAiResult::Payslip`       | Payslip subclass; self-registers via `register "Payslip"`; typed `field_for` accessors per field                           |
| `DocAiResult::W2`            | W2 subclass; self-registers via `register "W2"`; typed `field_for` accessors for all W2 fields                             |

---

## API Interface

### Endpoint

| Property       | Value                                                              |
|----------------|--------------------------------------------------------------------|
| URL            | `https://app-docai.platform-test-dev.navateam.com/v1/documents`   |
| Method         | `POST`                                                             |
| Query param    | `wait=true`                                                        |
| Content-Type   | `multipart/form-data`                                              |
| Authentication | None (unauthenticated — see Future Considerations)                 |

### Request

```
POST /v1/documents?wait=true
Content-Type: multipart/form-data

file=<binary file contents>
```

### Success Response (HTTP 200 — Payslip)

```json
{
  "job_id": "d773fa8f-3cc7-47d8-be78-4125c190c290",
  "status": "completed",
  "createdAt": "2026-02-23T18:26:50.830294+00:00",
  "completedAt": "2026-02-23T18:27:29.434195+00:00",
  "totalProcessingTimeSeconds": 38.6,
  "matchedDocumentClass": "Payslip",
  "message": "Document processed successfully",
  "fields": {
    "payperiodstartdate":      { "confidence": 0.91, "value": "2017-07-10" },
    "payperiodenddate":        { "confidence": 0.92, "value": "2017-07-23" },
    "paydate":                 { "confidence": 0.23, "value": "2017-08-04" },
    "currentgrosspay":         { "confidence": 0.93, "value": 1627.74 },
    "currentnetpay":           { "confidence": 0.87, "value": 1040.23 },
    "currenttotaldeductions":  { "confidence": 0.92, "value": 226.83 },
    "ytdgrosspay":             { "confidence": 0.88, "value": 28707.21 },
    "ytdnetpay":               { "confidence": 0.87, "value": 18396.25 },
    "ytdfederaltax":           { "confidence": 0.27, "value": 3319.78 },
    "ytdstatetax":             { "confidence": 0.02, "value": 1126 },
    "ytdtotaldeductions":      { "confidence": 0.93, "value": 3782.22 },
    "regularhourlyrate":       { "confidence": 0.93, "value": 20.346846 },
    "currency":                { "confidence": 0.90, "value": "USD" },
    "federalfilingstatus":     { "confidence": 0.89, "value": "Single" },
    "statefilingstatus":       { "confidence": 0.86, "value": "Single" },
    "payrollnumber":           { "confidence": 0.88, "value": "000000002214873" },
    "employeenumber":          { "confidence": 0.93, "value": "000000000" },
    "employeename.firstname":  { "confidence": 0.88, "value": "Jane" },
    "employeename.lastname":   { "confidence": 0.88, "value": "Doe" },
    "employeeaddress.line1":   { "confidence": 0.92, "value": "123 Franklin St" },
    "employeeaddress.city":    { "confidence": 0.86, "value": "CHAPEL HILL" },
    "employeeaddress.state":   { "confidence": 0.91, "value": "NC" },
    "employeeaddress.zipcode": { "confidence": 0.91, "value": "27517" },
    "companyaddress.line1":    { "confidence": 0.82, "value": "103 South Building" },
    "companyaddress.city":     { "confidence": 0.91, "value": "Chapel Hill" },
    "companyaddress.state":    { "confidence": 0.93, "value": "NC" },
    "companyaddress.zipcode":  { "confidence": 0.93, "value": "27599-9100" },
    "isgrosspayvali":          { "confidence": 0.87, "value": true }
  }
}
```

### Success Response (HTTP 200 — W2)

```json
{
  "job_id": "e8b21c94-5d4f-48a9-bc91-37d6f4a09c11",
  "status": "completed",
  "createdAt": "2026-02-23T20:14:12.105843+00:00",
  "completedAt": "2026-02-23T20:14:51.882017+00:00",
  "totalProcessingTimeSeconds": 39.8,
  "matchedDocumentClass": "W2",
  "message": "Document processed successfully",
  "fields": {
    "employerInfo.employerAddress":               { "confidence": 0.89, "value": "103 South Building, Chapel Hill, NC 27599" },
    "employerInfo.controlNumber":                 { "confidence": 0.85, "value": "000042" },
    "employerInfo.employerName":                  { "confidence": 0.92, "value": "University of North Carolina" },
    "employerInfo.ein":                           { "confidence": 0.94, "value": "56-6001393" },
    "employerInfo.employerZipCode":               { "confidence": 0.91, "value": "27599" },
    "filingInfo.ombNumber":                       { "confidence": 0.88, "value": "1545-0008" },
    "filingInfo.verificationCode":                { "confidence": 0.76, "value": "A1B2C3" },
    "other":                                      { "confidence": 0.70, "value": null },
    "federalTaxInfo.federalIncomeTax":            { "confidence": 0.93, "value": 3319.78 },
    "federalTaxInfo.allocatedTips":               { "confidence": 0.81, "value": 0 },
    "federalTaxInfo.socialSecurityTax":           { "confidence": 0.92, "value": 1982.44 },
    "federalTaxInfo.medicareTax":                 { "confidence": 0.91, "value": 463.61 },
    "employeeGeneralInfo.employeeNameSuffix":     { "confidence": 0.72, "value": null },
    "employeeGeneralInfo.employeeAddress":        { "confidence": 0.90, "value": "123 Franklin St, Chapel Hill, NC 27517" },
    "employeeGeneralInfo.employeeLastName":       { "confidence": 0.93, "value": "Doe" },
    "employeeGeneralInfo.employeeZipCode":        { "confidence": 0.91, "value": "27517" },
    "employeeGeneralInfo.firstName":              { "confidence": 0.93, "value": "Jane" },
    "employeeGeneralInfo.ssn":                    { "confidence": 0.88, "value": "***-**-1234" },
    "federalWageInfo.socialSecurityTips":         { "confidence": 0.83, "value": 0 },
    "federalWageInfo.wagesTipsOtherCompensation": { "confidence": 0.94, "value": 31964.00 },
    "federalWageInfo.medicareWagesTips":          { "confidence": 0.93, "value": 31964.00 },
    "federalWageInfo.socialSecurityWages":        { "confidence": 0.93, "value": 31964.00 },
    "nonqualifiedPlansIncom":                     { "confidence": 0.79, "value": 0 }
  }
}
```

### Failed Job Response (HTTP 200)

A job may complete with HTTP 200 but indicate a processing failure via `status: "failed"`:

```json
{
  "job_id": "a4187dd2-8ccd-4e6f-b7a7-164092e49eca",
  "status": "failed",
  "createdAt": "2026-02-23T23:37:40.608528+00:00",
  "error": "Handler handler failed: '>' not supported between instances of 'int' and 'ConfigDefaults'",
  "additionalInfo": "'>' not supported between instances of 'int' and 'ConfigDefaults'"
}
```

### HTTP-Level Error Response

```json
{ "detail": "There was an error parsing the body" }
```

### Field Reference (Payslip)

> **Note**: Response field names are **lowercased and concatenated** even though the official schema uses PascalCase (e.g., `payperiodstartdate` maps to `PayPeriodStartDate`). Dot-notation compound fields like `EmployeeName.FirstName` become `employeename.firstname` in the response.
>
> All data accessors return a `DocAiResult::FieldValue` wrapping the value and confidence score. Boolean validation flag accessors (`gross_pay_valid?` etc.) return `true`/`false` directly.

| API Field Key                 | Ruby Accessor                    | Value type inside `FieldValue` |
|-------------------------------|----------------------------------|---------|
| `payperiodstartdate`          | `pay_period_start_date`          | String  |
| `payperiodenddate`            | `pay_period_end_date`            | String  |
| `paydate`                     | `pay_date`                       | String  |
| `currentgrosspay`             | `current_gross_pay`              | Numeric |
| `currentnetpay`               | `current_net_pay`                | Numeric |
| `currenttotaldeductions`      | `current_total_deductions`       | Numeric |
| `ytdgrosspay`                 | `ytd_gross_pay`                  | Numeric |
| `ytdnetpay`                   | `ytd_net_pay`                    | Numeric |
| `ytdfederaltax`               | `ytd_federal_tax`                | Numeric |
| `ytdstatetax`                 | `ytd_state_tax`                  | Numeric |
| `ytdtotaldeductions`          | `ytd_total_deductions`           | Numeric |
| `regularhourlyrate`           | `regular_hourly_rate`            | Numeric |
| `holidayhourlyrate`           | `holiday_hourly_rate`            | Numeric |
| `currency`                    | `currency`                       | String  |
| `federalfilingstatus`         | `federal_filing_status`          | String  |
| `statefilingstatus`           | `state_filing_status`            | String  |
| `payrollnumber`               | `payroll_number`                 | String  |
| `employeenumber`              | `employee_number`                | String  |
| `employeename.firstname`      | `employee_first_name`            | String  |
| `employeename.middlename`     | `employee_middle_name`           | String  |
| `employeename.lastname`       | `employee_last_name`             | String  |
| `employeename.suffixname`     | `employee_suffix_name`           | String  |
| `employeeaddress.line1`       | `employee_address_line1`         | String  |
| `employeeaddress.line2`       | `employee_address_line2`         | String  |
| `employeeaddress.city`        | `employee_address_city`          | String  |
| `employeeaddress.state`       | `employee_address_state`         | String  |
| `employeeaddress.zipcode`     | `employee_address_zipcode`       | String  |
| `companyaddress.line1`        | `company_address_line1`          | String  |
| `companyaddress.line2`        | `company_address_line2`          | String  |
| `companyaddress.city`         | `company_address_city`           | String  |
| `companyaddress.state`        | `company_address_state`          | String  |
| `companyaddress.zipcode`      | `company_address_zipcode`        | String  |
| `isgrosspayvali`              | `gross_pay_valid?`               | Boolean |
| `isytdgrosspayhighest`        | `ytd_gross_pay_highest?`         | Boolean |
| `arefieldnamessufficient`     | `field_names_sufficient?`        | Boolean |

---

### Field Reference (W2)

> **Note**: W2 response field names use dot-notation groups (e.g., `employerInfo.employerName`). All accessors return a `DocAiResult::FieldValue`.
>
> `nonqualifiedPlansIncom` is a DocAI typo (truncated key). The Ruby accessor uses the correct spelling; `field_for` is called with the literal API key.

| API Field Key                                | Ruby Accessor                   | Group         | Value type inside `FieldValue` |
|----------------------------------------------|---------------------------------|---------------|--------------------------------|
| `employerInfo.employerAddress`               | `employer_address`              | Employer Info | String  |
| `employerInfo.controlNumber`                 | `employer_control_number`       | Employer Info | String  |
| `employerInfo.employerName`                  | `employer_name`                 | Employer Info | String  |
| `employerInfo.ein`                           | `employer_ein`                  | Employer Info | String  |
| `employerInfo.employerZipCode`               | `employer_zip_code`             | Employer Info | String  |
| `filingInfo.ombNumber`                       | `omb_number`                    | Filing Info   | String  |
| `filingInfo.verificationCode`                | `verification_code`             | Filing Info   | String  |
| `other`                                      | `other`                         | Other         | String  |
| `federalTaxInfo.federalIncomeTax`            | `federal_income_tax`            | Federal Tax   | Numeric |
| `federalTaxInfo.allocatedTips`               | `allocated_tips`                | Federal Tax   | Numeric |
| `federalTaxInfo.socialSecurityTax`           | `social_security_tax`           | Federal Tax   | Numeric |
| `federalTaxInfo.medicareTax`                 | `medicare_tax`                  | Federal Tax   | Numeric |
| `employeeGeneralInfo.employeeNameSuffix`     | `employee_name_suffix`          | Employee Info | String  |
| `employeeGeneralInfo.employeeAddress`        | `employee_address`              | Employee Info | String  |
| `employeeGeneralInfo.employeeLastName`       | `employee_last_name`            | Employee Info | String  |
| `employeeGeneralInfo.employeeZipCode`        | `employee_zip_code`             | Employee Info | String  |
| `employeeGeneralInfo.firstName`              | `employee_first_name`           | Employee Info | String  |
| `employeeGeneralInfo.ssn`                    | `employee_ssn`                  | Employee Info | String  |
| `federalWageInfo.socialSecurityTips`         | `social_security_tips`          | Federal Wages | Numeric |
| `federalWageInfo.wagesTipsOtherCompensation` | `wages_tips_other_compensation` | Federal Wages | Numeric |
| `federalWageInfo.medicareWagesTips`          | `medicare_wages_tips`           | Federal Wages | Numeric |
| `federalWageInfo.socialSecurityWages`        | `social_security_wages`         | Federal Wages | Numeric |
| `nonqualifiedPlansIncom`                     | `nonqualified_plans_income`     | Other         | Numeric |

---

## Error Handling

| Scenario                   | HTTP Status | Body                         | Handling                                                                                                             |
|----------------------------|-------------|------------------------------|----------------------------------------------------------------------------------------------------------------------|
| Bad request / parse failure | 4xx        | `{"detail": "..."}`          | `DocAiAdapter#handle_error` → raises `ApiError` with detail msg                                                      |
| Server error               | 5xx         | —                            | `BaseAdapter#handle_server_error` → raises `ServerError`                                                             |
| Network failure            | —           | —                            | `BaseAdapter#handle_connection_error` → raises `ApiError`                                                            |
| Request timeout (> 60s)    | —           | —                            | Faraday raises `TimeoutError` → caught as `ApiError` → `handle_integration_error` returns `nil`                      |
| DocAI processing failed    | 200         | `{"status":"failed",...}`    | `DocAiService` checks `result.failed?` → raises `ProcessingError`                                                    |
| Graceful degradation       | any         | —                            | `handle_integration_error` logs warning and returns `nil`; controller updates `StagedDocument` to `status: :failed`  |
| Document not a recognised income type | 200 | `{"matchedDocumentClass":"..."}` | Controller checks `SUPPORTED_RESULT_CLASSES.any?`; updates `StagedDocument` to `status: :rejected`; returns error in rendered template |

---

## Key Interfaces

### StagedDocument

Intermediate ActiveRecord model that owns an uploaded file and tracks its DocAI validation lifecycle. Retained permanently as an audit record. `belongs_to :user` records who uploaded the file; `belongs_to :stageable, polymorphic: true` links the document to whatever parent model consumes it (e.g., `Activity`, `Exemption`). The `extracted_fields` JSONB column stores the full raw DocAI `fields` response — including per-field confidence scores — so no data is lost at persistence time.

See [`examples/staged_document_migration.rb`](examples/staged_document_migration.rb) for the migration and [`examples/staged_document.rb`](examples/staged_document.rb) for the model.

**Blob sharing:** When a consuming controller calls `@parent.supporting_documents.attach(staged.file.blob)`, it creates a new `active_storage_attachments` row pointing at the same `ActiveStorage::Blob` — no S3 copy is made. Both the `StagedDocument` and the parent model reference the same physical file. Since `StagedDocument` records are never purged, there is no risk of the blob being deleted out from under the parent.

---

### DocumentStagingController

Entry point for all document uploads. Accepts multiple files via a standard HTML form POST, validates content type via server-side magic-byte detection (Marcel) and size per file, then processes all valid files **concurrently** on a dedicated `Concurrent::FixedThreadPool` — each file gets its own `Concurrent::Future` that builds a `StagedDocument` (associated with `current_user`), attaches the file, and saves atomically before delegating to `DocAiService`. The full raw API response (including confidence scores) is stored in `extracted_fields`. After all futures resolve, renders a template with prefilled fields and hidden signed_id inputs for each validated document. Total wall-clock time ≈ one DocAI call regardless of file count.

See [`examples/document_staging_controller.rb`](examples/document_staging_controller.rb) for the full implementation.

Field serialisation is no longer performed in the controller. The raw DocAI `fields` hash — containing `{ "value": ..., "confidence": ... }` pairs per field — is stored directly in the `extracted_fields` JSONB column. For form prefill, the `DocAiResult` subclasses provide a `to_prefill_fields` method that extracts just the values (see [DocAiResult subclasses](#docairesultpayslip-subclass-value-object)).

**Concurrency model**: `process_files_concurrently` dispatches each file to a `Concurrent::Future` executing on `DOC_AI_THREAD_POOL` — a dedicated `Concurrent::FixedThreadPool` that isolates DocAI concurrency from the `concurrent-ruby` global IO pool. This prevents burst upload traffic from starving other concurrent-ruby consumers in the process (e.g., ActiveStorage callbacks). The pool size defaults to `MAX_FILE_COUNT * 2` (4 threads) and is configurable via `doc_ai[:thread_pool_size]`. `current_user` is captured before threading because ActionController helpers are not thread-safe. Each Future checks out its own database connection via `ActiveRecord::Base.connection_pool.with_connection` to avoid contention on the request thread's connection. If any individual Future raises an unexpected exception, it is caught and returned as a generic error result — other files in the batch are not affected.

The template (`create.html.erb`) iterates over `@results`:
- For validated docs: renders prefilled fields (via `result.to_prefill_fields`) and a hidden `staged_document_signed_ids[]` input per doc
- For rejected/failed docs: renders an inline error message

> **Double-submit prevention**: The file upload form uses `data: { turbo_submits_with: t(".submitting") }` on the submit button (or equivalent `data-disable-with` attribute for non-Turbo forms) to disable the button after first click. Because DocAI processing takes ~38 seconds per file, the member must select all files at once before submitting — the button remains disabled until the response is rendered, preventing duplicate submissions.

> **Authorization**: `authorize :document, :create?` is called at the top of `#create` to enforce member authentication before any file processing. A corresponding `DocumentPolicy` must be created.

---

### DocAiAdapter

Extends `DataIntegration::BaseAdapter`. No auth headers — endpoint is currently unauthenticated.

The `analyze_document` method accepts an `ActiveStorage::Attached::One` object. Since `Faraday::UploadIO` requires a file path or IO object (not an ActiveStorage attachment), the adapter opens the blob as a `Tempfile` via `file.blob.open`, which streams the file from S3 to a local tempfile for the duration of the block.

See [`examples/doc_ai_adapter.rb`](examples/doc_ai_adapter.rb) for the full implementation.

### DocAiService

Extends `DataIntegration::BaseService`.

See [`examples/doc_ai_service.rb`](examples/doc_ai_service.rb) for the full implementation.

### DocAiResult::FieldValue

A lightweight struct wrapping the `value` and `confidence` score for a single extracted field. All subclass field accessors return a `FieldValue` (or `nil` if the field was absent from the response).

The `FieldValue` struct is defined inside `doc_ai_result.rb` (see [`examples/doc_ai_result.rb`](examples/doc_ai_result.rb)).

**Usage example:**

```ruby
result = DocAiService.new.analyze(file: uploaded_file)

gross_pay = result.current_gross_pay   # => #<data DocAiResult::FieldValue value=1627.74, confidence=0.93>
gross_pay.value          # => 1627.74
gross_pay.confidence     # => 0.93
gross_pay.low_confidence? # => false

result.pay_date.low_confidence?  # => true  (confidence: 0.23 — flag for staff review)
```

---

### DocAiResult (Base Value Object)

Holds the response envelope, the `FieldValue` accessor, and the self-registration factory. Extends `Strata::ValueObject`.

See [`examples/doc_ai_result.rb`](examples/doc_ai_result.rb) for the full implementation.

### DocAiResult::Payslip (Subclass Value Object)

Registers itself with the base class factory and exposes every Payslip schema field as an idiomatic Ruby snake_case method. Each accessor returns a `FieldValue` (or `nil` if the field was absent). Boolean validation flags are predicates that unwrap the value directly. `to_prefill_fields` returns a flat hash of values for form prefill — this is the only place field-to-form mapping is defined.

See [`examples/doc_ai_result/payslip.rb`](examples/doc_ai_result/payslip.rb) for the full implementation.

### DocAiResult::W2 (Subclass Value Object)

Registers itself with the base class factory and exposes all W2 schema fields as idiomatic Ruby snake_case methods grouped by document section. Each accessor returns a `FieldValue` (or `nil` if the field was absent).

> `nonqualifiedPlansIncom` is a DocAI typo (truncated key). The Ruby accessor uses the correct spelling; `field_for` is called with the literal API key.

See [`examples/doc_ai_result/w2.rb`](examples/doc_ai_result/w2.rb) for the full implementation.

### Extending for New Document Types

Adding support for a new document type (1099, bank statement, etc.) requires creating the subclass, calling `register`, and implementing `to_prefill_fields`. No changes to `DocAiResult` or `DocumentStagingController` are needed.

See [`examples/doc_ai_result/bank_statement.rb`](examples/doc_ai_result/bank_statement.rb) for an annotated example. After creating the file, add `require_relative "doc_ai_result/bank_statement"` inside the `DocAiResult` class body (before `REGISTRY.freeze`) alongside the existing requires.

---

## Files to Create

| File | Purpose |
|------|---------|
| `app/models/staged_document.rb` | `StagedDocument` model — status enum, `has_one_attached :file`, `extracted_fields` JSONB |
| `db/migrate/<timestamp>_create_staged_documents.rb` | Migration for `staged_documents` table (uuid pk, status, doc_ai_job_id, extracted_fields, activity_id) |
| `app/controllers/document_staging_controller.rb` | Validates uploads via Marcel magic-byte detection (PDF or JPG/JPEG, ≤30 MB per file); processes files concurrently on a dedicated `FixedThreadPool` via `Concurrent::Future`; builds + attaches + saves `StagedDocument` atomically per file; orchestrates DocAI; renders template with prefilled fields and signed IDs |
| `app/views/document_staging/create.html.erb` | Template rendered after multi-file upload; prefilled fields and hidden `staged_document_signed_ids[]` inputs per validated doc; inline errors for rejected/failed docs |
| `app/adapters/doc_ai_adapter.rb` | Extends `DataIntegration::BaseAdapter`; POSTs file via Faraday multipart |
| `app/services/doc_ai_service.rb` | Extends `DataIntegration::BaseService`; accepts ActiveStorage attachment, returns `DocAiResult` |
| `app/models/doc_ai_result.rb` | Base `Strata::ValueObject`; envelope fields, generic accessors, subclass factory |
| `app/models/doc_ai_result/payslip.rb` | `DocAiResult::Payslip` subclass; all Payslip snake_case field accessors |
| `app/models/doc_ai_result/w2.rb` | `DocAiResult::W2` subclass; all W2 snake_case field accessors grouped by section |
| `config/initializers/doc_ai.rb` | App config for env vars including `low_confidence_threshold` |
| `app/policies/document_policy.rb` | Pundit policy for `authorize :document, :create?` in `DocumentStagingController` |
| `spec/models/staged_document_spec.rb` | Model validations and enum tests |
| `spec/controllers/document_staging_controller_spec.rb` | Controller tests: file validation, concurrent multi-file processing, `StagedDocument` lifecycle, DocAI delegation, template rendering, error isolation between concurrent files |
| `spec/adapters/doc_ai_adapter_spec.rb` | Adapter tests (WebMock stubs) |
| `spec/services/doc_ai_service_spec.rb` | Service tests |
| `spec/models/doc_ai_result_spec.rb` | Base value object tests |
| `spec/models/doc_ai_result/payslip_spec.rb` | Payslip accessor tests |
| `spec/models/doc_ai_result/w2_spec.rb` | W2 accessor tests |

```
app/models/
  staged_document.rb
  doc_ai_result.rb
  doc_ai_result/
    payslip.rb
    w2.rb
app/views/document_staging/
  create.html.erb
spec/models/
  staged_document_spec.rb
  doc_ai_result_spec.rb
  doc_ai_result/
    payslip_spec.rb
    w2_spec.rb
```

## Files to Modify

| File | Change |
|------|--------|
| `Gemfile` | Add `faraday-multipart` if not already present |
| `local.env.example` | Add `DOC_AI_API_HOST`, `DOC_AI_TIMEOUT_SECONDS`, `DOC_AI_LOW_CONFIDENCE_THRESHOLD` |
| `config/routes.rb` | Add `POST /document_staging` route for `DocumentStagingController#create` |
| `app/controllers/activities_controller.rb` | Accept `staged_document_signed_ids: []` (array) in permitted params; iterate via `find_signed`, attach blobs, set polymorphic `stageable`, and skip upload redirect when any are present |

---

## Route

```ruby
# config/routes.rb (inside localized block)
resource :document_staging, only: [:create], controller: "document_staging"
```

This generates `POST /document_staging` → `DocumentStagingController#create`. The route is placed inside the `localized` block so it participates in locale-scoped routing via `route_translator`.

---

## Configuration

```ruby
# config/initializers/doc_ai.rb
Rails.application.config.doc_ai = {
  api_host:                 ENV.fetch("DOC_AI_API_HOST"),
  timeout_seconds:          ENV.fetch("DOC_AI_TIMEOUT_SECONDS", "60").to_i,
  low_confidence_threshold: ENV.fetch("DOC_AI_LOW_CONFIDENCE_THRESHOLD", "0.7").to_f,
  thread_pool_size:         ENV.fetch("DOC_AI_THREAD_POOL_SIZE", "4").to_i
}
```

```bash
# local.env.example
DOC_AI_API_HOST=https://app-docai.platform-test-dev.navateam.com
DOC_AI_TIMEOUT_SECONDS=60
DOC_AI_LOW_CONFIDENCE_THRESHOLD=0.7
DOC_AI_THREAD_POOL_SIZE=4
```

| Variable                          | Purpose                                                      | Required |
|-----------------------------------|--------------------------------------------------------------|----------|
| `DOC_AI_API_HOST`                 | DocAI base URL (per environment)                             | Yes      |
| `DOC_AI_TIMEOUT_SECONDS`          | Max seconds to wait for a DocAI response (default: 60)       | No       |
| `DOC_AI_LOW_CONFIDENCE_THRESHOLD` | Minimum confidence score before `low_confidence?` returns `true` (default: 0.7) | No |
| `DOC_AI_THREAD_POOL_SIZE`         | Number of threads in the dedicated DocAI `FixedThreadPool` (default: 4)         | No |

> **Web server timeout**: Because DocAI validation runs concurrently on background threads but the web request thread blocks until all futures resolve (up to 60 seconds), Puma and any rack-timeout middleware (e.g., `Rack::Timeout`) must be configured to allow requests longer than 60 seconds for the upload endpoint. A recommended minimum is 75 seconds to provide headroom above the Faraday timeout. Note: concurrent processing means total time is ~60 seconds regardless of file count.
>
> **Database connection pool**: Each concurrent file occupies one ActiveRecord connection for the duration of its processing (~38–60 seconds). With `MAX_FILE_COUNT = 2`, each upload request uses up to 2 additional connections. Ensure `database.yml` `pool` size accommodates this on top of Puma worker connections.

---

## Decisions

### Synchronous `wait=true` with a 60-second timeout

**Decision**: Use the `wait=true` query parameter to block until DocAI completes processing, with a Faraday read timeout of 60 seconds (`open_timeout: 10s`).

**Rationale**: Document validation is user-facing and must complete within the upload request/response cycle. When a member submits a pay stub, OSCER must immediately confirm whether the document is a valid Payslip — background processing would require polling or WebSockets, adding significant complexity with no benefit. Using `wait=true` keeps the flow simple: the controller calls the service, the service calls the adapter, and the result is returned synchronously to the member. DocAI typically responds in ~38 seconds; the 60-second timeout provides headroom for upload latency and variable processing times while bounding the request to a known maximum.

**Tradeoff**: A web request thread is held for up to 60 seconds per upload (regardless of file count, since files are processed concurrently — see below). Puma and any rack-timeout middleware must be configured with a limit above 60 seconds (see Configuration). Under high concurrent upload load, this may exhaust Puma threads; consider a dedicated thread pool or route-level concurrency controls for the upload endpoint if this becomes a bottleneck.

### Concurrent multi-file processing via `Concurrent::Future` on a dedicated thread pool

**Decision**: When multiple files are uploaded, each file is dispatched to its own `Concurrent::Future` executing on `DOC_AI_THREAD_POOL` — a dedicated `Concurrent::FixedThreadPool`. All DocAI calls execute in parallel. The controller waits for all futures to resolve before rendering the response.

**Rationale**: DocAI processing takes ~38 seconds per file. Sequential processing of 3 files would block the response for ~114 seconds — beyond any reasonable request timeout and a poor user experience. Concurrent processing keeps total wall-clock time at ~38 seconds regardless of file count. `Concurrent::Future` (from `concurrent-ruby`, which ships with Rails as a dependency) provides managed thread pooling. A dedicated `FixedThreadPool` is used instead of the global IO pool to isolate DocAI concurrency from the rest of the application — burst upload traffic cannot starve other concurrent-ruby consumers (e.g., ActiveStorage callbacks). The pool size defaults to `MAX_FILE_COUNT * 2` (4 threads) and is configurable via `doc_ai[:thread_pool_size]`. Each Future checks out its own database connection via `ActiveRecord::Base.connection_pool.with_connection`, ensuring clean connection lifecycle and no contention with the request thread. `current_user` is captured before threading because ActionController helpers are not thread-safe.

**Tradeoff**: Each concurrent file consumes one thread from the dedicated pool and one connection from the ActiveRecord connection pool. `MAX_FILE_COUNT` (2) caps the maximum concurrent futures per request, bounding resource consumption. The database pool size (`pool` in `database.yml`) must be large enough to accommodate 2 additional connections per concurrent upload request on top of Puma worker connections. If the pool is undersized, a Future will block waiting for a connection, degrading to sequential behavior rather than failing. If the dedicated thread pool is exhausted (all threads occupied by concurrent uploads from other requests), new futures will queue until a thread becomes available — this degrades latency gracefully rather than failing. Error isolation is per-Future: if one file's processing raises an exception, the others are unaffected and the failed file returns a generic error result.

### Subclass-per-document-class value objects with self-registration

**Decision**: Model each document type (Payslip, W2, 1099, etc.) as a subclass of `DocAiResult`. Each subclass self-registers via `register "ClassName"`, populating a `REGISTRY` hash on the base class at load time. The factory method dispatches using `REGISTRY` rather than a statically-maintained map.

**Rationale**: Typed subclasses provide method-name discoverability, make callers self-documenting, and allow document-type-specific validation. Self-registration keeps the base class closed to modification: adding a new document type requires only creating its subclass and calling `register` — `DocAiResult` itself does not need to change.

**Tradeoff**: Subclass files must be required (via `require_relative` at the bottom of `doc_ai_result.rb`) so their `register` calls execute before `from_response` is invoked. Rails eager loading handles this automatically in production; in development/test, the explicit requires guarantee consistent behaviour regardless of autoload order.

### Confidence as a first-class concept — in-memory via `FieldValue`, persisted via raw JSONB

**Decision**: All field accessors on `DocAiResult` subclasses return a `DocAiResult::FieldValue` struct — a `Data.define` value object wrapping `value` and `confidence` together — rather than raw values. A `low_confidence?` predicate (threshold: 0.7) is built into the struct. The full raw DocAI `fields` hash (containing `{ "value": ..., "confidence": ... }` per field) is stored as-is in the `StagedDocument#extracted_fields` JSONB column, preserving confidence scores at rest for staff review and audit.

**Rationale**: Confidence scores are part of every field the API returns. Exposing them as a paired struct rather than a separate accessor call makes it impossible for callers to accidentally use an extracted value without having access to its reliability signal. Storing the raw response in JSONB — rather than a stripped-down values-only hash — ensures no data is lost at persistence time. Staff can review low-confidence fields, and developers can debug extraction issues, without replaying the DocAI call. The `to_prefill_fields` method on each subclass provides a clean values-only hash for form rendering.

**Tradeoff**: Callers that previously compared `result.current_gross_pay == 1627.74` now compare `result.current_gross_pay.value == 1627.74`. Boolean validation flag accessors (`gross_pay_valid?` etc.) remain plain predicates by unwrapping the value directly, since confidence on a flag is not semantically meaningful to callers. The JSONB column stores more data per row than a values-only approach, but the overhead is negligible relative to the S3 blob.

### `StagedDocument` as audit record with full response retention

**Decision**: Create a `StagedDocument` ActiveRecord model that owns the uploaded file via `has_one_attached :file`, belongs to a `user`, and tracks the full DocAI validation lifecycle (status, `job_id`, `matched_class`, `extracted_fields`, `validated_at`). The `extracted_fields` JSONB column stores the complete raw DocAI `fields` response — including per-field confidence scores — not a stripped-down subset. A polymorphic `belongs_to :stageable` links the document to whatever parent model consumes it. Records are retained permanently; they are never purged.

**Rationale**: Unlike the previous staging copy (deleted after promotion), `StagedDocument` rows serve as a permanent audit trail. Storing the full API response preserves confidence scores alongside extracted values, enabling staff to review low-confidence fields and developers to debug extraction issues without replaying the DocAI call. The `user_id` foreign key enables per-member audit queries (e.g., failure rates, upload history). The polymorphic `stageable` association allows the same staging mechanism to serve multiple consuming models (Activity, Exemption, etc.) without schema changes. ActiveStorage handles S3 bucket configuration transparently, eliminating the dual-bucket abstraction and the associated orphan-object risk.

**Tradeoff**: `staged_documents` rows accumulate over time. For high-volume deployments, a periodic archival or soft-delete strategy may be desirable — but this is an operational concern, not an architectural one. The table schema is designed to support it.

### Blob sharing, not blob copying

**Decision**: When a consuming controller attaches a validated document to a parent model, it calls `@parent.supporting_documents.attach(staged.file.blob)` — passing the existing `ActiveStorage::Blob` object rather than re-uploading the file.

**Rationale**: Attaching a blob creates a new `active_storage_attachments` row pointing at the same `active_storage_blobs` record and the same S3 object. No data is duplicated in storage. Since `StagedDocument` records are never purged, the blob is safe from premature deletion even after it is shared with a parent model.

**Tradeoff**: The `StagedDocument.file` attachment and the parent's attachment reference the same S3 object. Purging one attachment would affect the other. The retention policy (never purge `StagedDocument`) prevents this; any future purge logic must be aware of the sharing.

### `signed_id` over raw UUID for the hand-off token

**Decision**: `DocumentStagingController` returns `staged_document.signed_id(expires_in: 1.hour)` as the hand-off token. Consuming controllers resolve it with `StagedDocument.find_signed(sid)` and set the polymorphic `stageable` association to their parent model.

**Rationale**: A raw UUID would allow IDOR — a member could substitute another member's `staged_document_id` in the form params and attach a document they did not upload. The signed ID is HMAC-signed via `ActiveRecord::SignedId`, so it cannot be forged or tampered with. The 1-hour expiry prevents stale hidden fields from attaching old documents. `StagedDocument.find_signed` resolves the token in one call with no manual authorization check needed. Because `StagedDocument` uses a polymorphic `stageable` association rather than a fixed `activity_id`, the same signed ID mechanism works for any consuming model — no purpose scope is needed.

**Tradeoff**: If the member's session takes longer than 1 hour between file selection and form submission, the signed ID will have expired. `find_signed` returns `nil`, and the consuming controller falls back to the existing documents upload page — consistent with the graceful degradation behavior for DocAI unavailability.

### `DocAiService` receives an ActiveStorage attachment, not a raw file

**Decision**: The controller passes `staged_document.file` (an `ActiveStorage::Attached::One` object) to `DocAiService`, after attaching the upload to the `StagedDocument`. The adapter opens the blob as a `Tempfile` via `file.blob.open` and passes the IO to `Faraday::Multipart::FilePart` for the multipart POST.

**Rationale**: Using the ActiveStorage attachment as the input ensures the service always works with the stored copy of the file, not a transient HTTP upload object that may be garbage collected. `blob.open` streams the file from S3 to a local tempfile for the duration of the block, providing a standard IO object that Faraday's multipart middleware can consume.

**Tradeoff**: `blob.open` downloads the file from S3 to a local tempfile, adding latency proportional to file size. For files up to 30 MB this is acceptable within the 60-second timeout budget. Test doubles must provide a blob-like object that responds to `.open { |io| }`, `.content_type`, and `.filename`.

### Graceful degradation on integration errors

**Decision**: `handle_integration_error` logs a warning and returns `nil` rather than propagating the exception to the caller.

**Rationale**: Consistent with the `DataIntegration::BaseService` pattern used by `VeteranDisabilityService`. Document analysis is an enhancement to existing workflows; failure should not block certification or exemption processing.

**Tradeoff**: Callers must handle `nil` returns explicitly and must not assume a result is always present.

---

## Future Considerations

### Authentication / Security

The DocAI endpoint currently has **no authentication**. Once the security model is defined, the adapter will need to be updated to include the appropriate credentials. The `DataIntegration::BaseAdapter` hook system (`before_request`) is the appropriate place to inject auth headers:

```ruby
# Example — implementation TBD once auth is defined
before_request :set_auth_header

def set_auth_header
  # @connection.headers["Authorization"] = "Bearer #{...}"
end
```
