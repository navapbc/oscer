# Direct Upload Approach Comparison: Custom vs Active Storage

## Executive Summary

OSCER batch upload v2 requires direct browser-to-S3 uploads to handle large CSV files (up to 5GB) without consuming Rails memory. This document compares two approaches:

1. **Custom Implementation** (current): Custom Stimulus controller, presigned URL endpoint, manual storage key management (~385 lines)
2. **Active Storage Direct Upload**: Rails built-in direct upload functionality (~50 lines)

Both achieve the same outcome: uploading files directly from browser to S3 without touching Rails memory. The key difference is **maintainability for multi-state deployments** where state IT teams will maintain this system long-term.

**Recommendation**: Adopt Active Storage Direct Upload. Provides same functionality with 85% less code and leverages Rails conventions that state IT teams already know.

---

## Problem Statement

### The Upload Challenge

OSCER processes large CSV files containing hundreds of thousands of records (files typically measure in hundreds of MB, with support up to 5GB). Standard Rails file uploads:
- Load entire file into Rails memory (hundreds of MB per concurrent upload)
- Memory pressure causes instability under load
- Files count against request timeout (30-60s)
- Cannot support files larger than available memory

### Solution Requirements

Both approaches must:
1. Upload directly browser → S3 (bypass Rails)
2. Use presigned URLs with short expiration (1 hour)
3. Validate file size, type, and sanitize filenames
4. Work with S3Adapter interface (cloud-agnostic)
5. Stream from S3 in background jobs

---

## Approach Comparison

### Custom Implementation (Current)

**Flow**: Browser → Rails (get presigned URL) → Browser → S3 → Browser → Rails (confirm) → Background Job

**Components**:
- Stimulus controller (153 lines): Manages presigned URL fetch, upload to S3, form submission
- Custom endpoint (44 lines): `/presigned_url` action generates signed URLs
- SignedUrlService (37 lines): Generates storage keys, delegates to adapter
- Controller create action (35 lines): Validates storage_key format, sanitizes filename

**Total**: ~385 lines of implementation code

```javascript
// Custom Stimulus controller
async uploadFile(event) {
  // Get presigned URL from custom endpoint
  const { url, key } = await fetch('/staff/certification_batch_uploads/presigned_url', {
    method: 'POST',
    body: JSON.stringify({ filename: file.name })
  }).then(r => r.json())

  // Upload to S3
  await fetch(url, { method: 'PUT', body: file })

  // Submit form with storage_key
  this.storageKeyTarget.value = key
  this.element.submit()
}
```

**Storage Key Format**: `batch-uploads/{uuid}/{filename}`

### Active Storage Direct Upload

**Flow**: Browser → Active Storage endpoint → Browser → S3 → Browser → Rails (attach blob) → Background Job

**Components**:
- Rails built-in JavaScript: Handles presigned URL, upload, form submission (no custom code required)
- Optional Stimulus: Active Storage fires events (`direct-upload:progress`, etc.) that make it easy to add UX upgrades like progress bars
- Rails built-in endpoint: `/rails/active_storage/direct_uploads`
- Controller create action (20 lines): Attaches blob, creates record
- Blob cleanup job (30 lines): Removes orphaned blobs

**Total**: ~50 lines of implementation code (basic); optional Stimulus for UX enhancements

```erb
<%# View - basic implementation, no custom JavaScript required %>
<%= form.file_field :csv_file, direct_upload: true %>
```

```ruby
# Controller - minimal
def create
  @batch_upload = CertificationBatchUpload.new(
    filename: params[:csv_file].original_filename,
    uploader: current_user
  )
  @batch_upload.file.attach(params[:csv_file])
  @batch_upload.save
  ProcessCertificationBatchUploadJob.perform_later(@batch_upload.id)
end
```

**Storage Key Format**: Active Storage managed (e.g., `variants/abc123/file`)

---

## Tradeoffs Analysis

### Code Complexity

| Metric | Custom | Active Storage |
|--------|--------|----------------|
| Implementation | ~385 lines | ~50 lines |
| Test coverage | ~10 test files | ~3 test files |
| JavaScript | 153 lines Stimulus | Rails built-in |
| Error handling | Manual | Rails conventions |

**Maintenance Impact**:
- Custom requires understanding presigned URL flow, Stimulus lifecycle, storage key validation
- Active Storage follows Rails conventions most developers already know

### Database Overhead

| Aspect | Custom | Active Storage |
|--------|--------|----------------|
| Records per upload | 1 | 3 (upload + blob + attachment) |
| Cleanup needed | No | Yes (orphaned blobs) |

**Analysis**: Active Storage creates 2 additional rows per upload (blob + attachment). PostgreSQL handles this additional overhead trivially at any reasonable upload volume - the database impact is negligible compared to maintainability benefits.

### Storage Key Management

Both work with CsvStreamReader:
```ruby
# Custom
reader.each_chunk(batch_upload.storage_key) { |records| ... }

# Active Storage
reader.each_chunk(batch_upload.file.blob.key) { |records| ... }
```

Custom format (`batch-uploads/{uuid}/{filename}`) is more readable for debugging. Active Storage format is opaque but doesn't matter - it's abstracted. Both work identically.

### Security

Both satisfy security requirements:

| Concern | Custom | Active Storage |
|---------|--------|----------------|
| Presigned URL expiration | Manual (1 hour) | Rails built-in (1 hour) |
| Filename sanitization | Manual | Rails built-in |
| Path traversal protection | Regex validation | Rails built-in |
| File type validation | Manual | Rails validations |

Active Storage security is battle-tested across thousands of production Rails apps.

### Performance

Identical performance:
- Both: Browser uploads directly to S3 (no Rails memory)
- Both: Background job streams from S3
- Active Storage database inserts add <1ms overhead (negligible)

### Developer Onboarding

**Custom**:
- Must understand custom presigned URL flow
- Must understand Stimulus controller
- Must understand storage key validation regex
- Unfamiliar patterns (no other Rails apps do this)

**Active Storage**:
- Standard Rails pattern most developers know
- Rails guides readily available
- Community support (Stack Overflow, forums)

### Rails Upgrade Path

**Custom**:
- Must test custom Stimulus controller with new Rails/Stimulus versions
- Must test custom endpoint with Rails routing changes
- Breaking changes require custom patches

**Active Storage**:
- Maintained by Rails core team
- Stable API since Rails 5.2 (2018)
- Upgrade issues documented in Rails guides
- Community identifies problems early

### Multi-State Deployment Context

OSCER is deployed by multiple state Medicaid agencies who maintain their instances. Every line of custom code is:
- Knowledge transfer burden when staff changes
- Upgrade testing burden
- Documentation maintenance burden
- Potential security vulnerability

**Custom**: State teams must understand custom patterns
**Active Storage**: State teams already know Rails conventions

---

## Decision Criteria

### Choose Custom If:

1. Storage key format critical to external integrations (not applicable - no external dependencies)
2. Database overhead prohibitive (not applicable - 2 extra rows negligible)
3. Rails upgrade not planned (not applicable - OSCER follows Rails LTS)

### Choose Active Storage If:

1. ✓ Minimizing long-term maintenance burden matters (critical for multi-state deployment)
2. ✓ Developer onboarding time matters (state IT teams have turnover)
3. ✓ Rails conventions should be followed (Rails Omakase philosophy)
4. ✓ Community support valuable (Active Storage used widely)
5. ✓ Code complexity should be minimized (385 vs 50 lines)

---

## Recommendation

**Adopt Active Storage Direct Upload.**

### Rationale

1. **Code Reduction**: 385 lines → 50 lines (85% less code to maintain)
2. **Rails Conventions**: State teams already understand Active Storage
3. **Battle-tested**: Used by thousands of production Rails apps
4. **Stable API**: Rails core team maintains it
5. **No Performance Cost**: Identical upload and processing performance
6. **Minimal Database Cost**: 2 extra rows per upload is trivial

### Migration Strategy

**Context**: Batch upload v2 is pre-production (behind `FEATURE_BATCH_UPLOAD_V2` flag). No production data uses custom `storage_key` approach, enabling clean migration to Active Storage without backward compatibility concerns.

**Phase 1: Update backend to use Active Storage** (Issue #208, Part 1)
1. Add/verify Active Storage `has_one_attached :file` on `CertificationBatchUpload`
2. Update `ProcessCertificationBatchUploadJob.process_streaming` to use `batch_upload.file.blob.key`
3. Update model methods (`uses_cloud_storage?` → check for blob presence)
4. Remove `storage_key` column (migration: `remove_column :certification_batch_uploads, :storage_key`)
5. Remove `SignedUrlService` (no longer needed)
6. Update tests to use Active Storage fixtures

**Phase 2: Implement UI with Active Storage Direct Upload** (Issue #208, Part 2)
1. Replace custom presigned URL controller action with Active Storage approach
2. Use `<%= form.file_field :csv_file, direct_upload: true %>` in view
3. Optionally add Stimulus for progress bar (listen to `direct-upload:progress` events)
4. Remove custom Stimulus upload controller (if not needed for UX)
5. Update tests

**Result**: Clean architecture using Rails conventions. V1 and V2 both use Active Storage; V2 adds streaming + parallel chunk processing. No technical debt from supporting dual upload paths.

---

## Open Questions

### 1. Blob Cleanup Frequency

**Question**: How often should orphaned blobs be cleaned up?

**Recommendation**: Daily cleanup of blobs older than 24 hours (failed uploads unlikely to resume after 24h).

---

## Code Comparison

### Custom Controller (79 lines)

```ruby
# POST /presigned_url - custom endpoint
def presigned_url
  authorize CertificationBatchUpload, :create?
  filename = params[:filename]

  if filename.blank?
    render json: { error: "Filename required" }, status: :unprocessable_content
    return
  end

  unless filename.end_with?(".csv")
    render json: { error: "CSV only" }, status: :unprocessable_content
    return
  end

  sanitized_filename = sanitize_filename(filename)
  result = SignedUrlService.new.generate_upload_url(
    filename: sanitized_filename,
    content_type: "text/csv"
  )

  render json: { url: result[:url], key: result[:key] }
end

# POST /certification_batch_uploads - confirm upload
def create_with_v2_flow
  storage_key = params[:storage_key]
  filename = params[:filename]

  # Validate format to prevent path traversal
  unless storage_key&.match?(%r{\Abatch-uploads/[0-9a-f-]{36}/[^/]+\z})
    render json: { error: "Invalid storage key" }, status: :unprocessable_content
    return
  end

  sanitized_filename = sanitize_filename(filename)

  @batch_upload = CertificationBatchUploadOrchestrator.new.initiate(
    source_type: :ui,
    filename: sanitized_filename,
    storage_key: storage_key,
    uploader: current_user
  )

  redirect_to certification_batch_upload_path(@batch_upload)
rescue CertificationBatchUploadOrchestrator::FileNotFoundError => e
  redirect_to new_certification_batch_upload_path, alert: "File not found"
end

private

def sanitize_filename(filename)
  return nil if filename.blank?
  clean_filename = filename.tr("\x00", "")
  File.basename(clean_filename)
    .gsub(/\s+/, "_")
    .gsub(/[^\w.-]/, "_")
    .truncate(255, omission: "")
end
```

### Active Storage Controller (20 lines)

```ruby
# POST /certification_batch_uploads
def create
  uploaded_file = params[:csv_file]

  if uploaded_file.blank?
    flash.now[:alert] = "Please select a CSV file"
    render :new, status: :unprocessable_content
    return
  end

  @batch_upload = CertificationBatchUpload.new(
    filename: uploaded_file.original_filename,
    uploader: current_user
  )
  @batch_upload.file.attach(uploaded_file)

  if @batch_upload.save
    ProcessCertificationBatchUploadJob.perform_later(@batch_upload.id)
    redirect_to certification_batch_uploads_path, notice: "File uploaded"
  else
    redirect_to new_certification_batch_upload_path,
                alert: @batch_upload.errors.full_messages.join(', ')
  end
end
```

**Key Differences**:
- Custom: Separate presigned URL endpoint + create action + manual validation
- Active Storage: Single create action, Rails handles presigned URLs and validation

---

## References

- [Active Storage Direct Upload Guide](https://guides.rubyonrails.org/active_storage_overview.html#direct-uploads)
- [Batch Upload Architecture](./batch-upload.md)
- OSCER Feature Flags: `docs/feature-flags.md`
