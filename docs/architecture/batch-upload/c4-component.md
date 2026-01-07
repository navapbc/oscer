# C4 Level 3: Component Diagram

## Batch Upload System - Component Architecture

This document describes the internal components within the Web Application and Background Workers containers.

## Web Application Components

```mermaid
flowchart TB
    subgraph webApp [Web Application Container]
        subgraph controllers [Controllers]
            BatchUploadsController[BatchUploadsController]
            BatchUploadsAPIController[API::BatchUploadsController]
        end

        subgraph services [Services]
            PresignedUrlService[PresignedUrlService]
            BatchUploadOrchestrator[BatchUploadOrchestrator]
        end

        subgraph models [Models]
            BatchUpload[BatchUpload]
            BatchUploadAuditLog[BatchUploadAuditLog]
            BatchUploadError[BatchUploadError]
        end
    end

    Client[Client] --> BatchUploadsController
    ExternalAPI[External API] --> BatchUploadsAPIController

    BatchUploadsController --> PresignedUrlService
    BatchUploadsController --> BatchUploadOrchestrator
    BatchUploadsAPIController --> BatchUploadOrchestrator

    BatchUploadOrchestrator --> BatchUpload
    PresignedUrlService --> S3[(S3)]
    BatchUploadOrchestrator --> JobQueue[(Redis Queue)]
```

## Background Worker Components

```mermaid
flowchart TB
    subgraph workers [Background Workers Container]
        subgraph jobs [Jobs]
            ProcessBatchUploadJob[ProcessBatchUploadJob]
            ProcessChunkJob[ProcessChunkJob]
            SyncFtpFilesJob[SyncFtpFilesJob]
        end

        subgraph services [Services]
            S3StreamingReader[S3StreamingReader]
            ChunkProcessor[ChunkProcessor]
            UnifiedRecordProcessor[UnifiedRecordProcessor]
            AuditLogger[AuditLogger]
            MetricsReporter[MetricsReporter]
        end

        subgraph validators [Validators]
            SchemaValidator[SchemaValidator]
            BusinessRuleValidator[BusinessRuleValidator]
            DuplicateChecker[DuplicateChecker]
        end
    end

    Queue[(Redis Queue)] --> ProcessBatchUploadJob
    ProcessBatchUploadJob --> S3StreamingReader
    S3StreamingReader --> ChunkProcessor
    ChunkProcessor --> ProcessChunkJob
    ProcessChunkJob --> UnifiedRecordProcessor

    UnifiedRecordProcessor --> SchemaValidator
    UnifiedRecordProcessor --> BusinessRuleValidator
    UnifiedRecordProcessor --> DuplicateChecker

    ChunkProcessor --> AuditLogger
    ChunkProcessor --> MetricsReporter

    S3StreamingReader --> S3[(S3)]
    AuditLogger --> DB[(PostgreSQL)]
    MetricsReporter --> APM[Datadog]
```

## Component Descriptions

### Controllers

| Component                       | Responsibility                                                                 |
| ------------------------------- | ------------------------------------------------------------------------------ |
| **BatchUploadsController**      | Handles staff UI requests for file uploads, status checks, and dashboard views |
| **API::BatchUploadsController** | RESTful API for external systems to submit batch uploads programmatically      |

### Services (Web Application)

| Component                   | Responsibility                                                                                 |
| --------------------------- | ---------------------------------------------------------------------------------------------- |
| **PresignedUrlService**     | Generates S3 presigned URLs for direct browser uploads, bypassing the Rails server             |
| **BatchUploadOrchestrator** | Central entry point for all upload sources; creates BatchUpload record and enqueues processing |

### Jobs

| Component                 | Responsibility                                                       |
| ------------------------- | -------------------------------------------------------------------- |
| **ProcessBatchUploadJob** | Main job that orchestrates file streaming and chunk distribution     |
| **ProcessChunkJob**       | Processes a single chunk of records; can run in parallel             |
| **SyncFtpFilesJob**       | Scheduled job that checks for new FTP files and initiates processing |

### Services (Background Workers)

| Component                  | Responsibility                                                          |
| -------------------------- | ----------------------------------------------------------------------- |
| **S3StreamingReader**      | Streams S3 objects without loading entire file into memory              |
| **ChunkProcessor**         | Splits stream into configurable chunks, coordinates parallel processing |
| **UnifiedRecordProcessor** | Single business logic processor used by ALL sources (UI, API, FTP, S3)  |
| **AuditLogger**            | Writes aggregated audit entries to `batch_upload_audit_logs` table      |
| **MetricsReporter**        | Sends custom metrics to Datadog APM                                     |

### Validators

| Component                 | Responsibility                                          |
| ------------------------- | ------------------------------------------------------- |
| **SchemaValidator**       | Validates CSV structure, required columns, data types   |
| **BusinessRuleValidator** | Applies business rules (date ranges, value constraints) |
| **DuplicateChecker**      | Checks for duplicate records (idempotency)              |

## Unified Record Processing Flow

All upload sources converge to the same processing logic:

```mermaid
flowchart TB
    subgraph sources [Upload Sources]
        UI[Staff UI Upload]
        API[External API]
        FTP[FTP Sync]
        S3Event[S3 Event Trigger]
    end

    subgraph orchestration [Orchestration Layer]
        Orchestrator[BatchUploadOrchestrator]
    end

    subgraph processing [Unified Processing]
        Stream[S3StreamingReader]
        Chunk[ChunkProcessor]
        Process[UnifiedRecordProcessor]
    end

    subgraph business [Business Logic]
        Validate[Validation]
        Transform[Transformation]
        Persist[Persistence]
        Trigger[BusinessProcess Trigger]
    end

    UI --> Orchestrator
    API --> Orchestrator
    FTP --> Orchestrator
    S3Event --> Orchestrator

    Orchestrator --> Stream
    Stream --> Chunk
    Chunk --> Process

    Process --> Validate
    Validate --> Transform
    Transform --> Persist
    Persist --> Trigger
```

## Key Component Interfaces

### BatchUploadOrchestrator

```ruby
class BatchUploadOrchestrator
  # Unified entry point for all upload sources
  # @param source_type [Symbol] :ui, :api, :ftp, :s3_event
  # @param s3_key [String] S3 object key
  # @param metadata [Hash] Source-specific metadata
  # @return [BatchUpload] Created batch upload record
  def initiate(source_type:, s3_key:, metadata: {})
    # 1. Create BatchUpload record
    # 2. Enqueue ProcessBatchUploadJob
    # 3. Return batch upload for status tracking
  end
end
```

### S3StreamingReader

```ruby
class S3StreamingReader
  # Streams S3 object in chunks without loading entire file
  # @param s3_key [String] S3 object key
  # @param chunk_size [Integer] Number of records per chunk (default: 1000)
  # @yield [Array<Hash>] Chunk of parsed records
  def each_chunk(s3_key, chunk_size: 1000)
    # Uses S3 GetObject with streaming response
    # Parses CSV incrementally
    # Yields chunks as they're ready
  end
end
```

### UnifiedRecordProcessor

```ruby
class UnifiedRecordProcessor
  # Processes a single record regardless of source
  # @param record [Hash] Parsed record data
  # @param context [ProcessingContext] Batch context
  # @return [ProcessingResult] Success or failure with details
  def process(record, context)
    # 1. Validate schema
    # 2. Check for duplicates
    # 3. Apply business rules
    # 4. Transform data
    # 5. Persist record
    # 6. Trigger business process if needed
  end
end
```

### AuditLogger

```ruby
class AuditLogger
  # Logs aggregated chunk processing results
  # Does NOT log individual records (for scale)
  def log_chunk_processed(batch_upload_id:, chunk_number:,
                          succeeded:, failed:, duration_ms:)
    BatchUploadAuditLog.create!(
      batch_upload_id: batch_upload_id,
      event_type: 'chunk_processed',
      chunk_number: chunk_number,
      succeeded_count: succeeded,
      failed_count: failed,
      duration_ms: duration_ms
    )
  end

  # Only logs individual records that FAILED
  def log_error(batch_upload_id:, row_number:, error_code:,
                error_message:, row_data:)
    BatchUploadError.create!(
      batch_upload_id: batch_upload_id,
      row_number: row_number,
      error_code: error_code,
      error_message: error_message,
      row_data: row_data
    )
  end
end
```

## Parallel Processing Strategy

```mermaid
flowchart TB
    subgraph main [Main Job]
        ProcessBatchUploadJob
    end

    subgraph streaming [Streaming Phase]
        S3StreamingReader
    end

    subgraph parallel [Parallel Chunk Processing]
        Chunk1[ProcessChunkJob 1]
        Chunk2[ProcessChunkJob 2]
        Chunk3[ProcessChunkJob 3]
        ChunkN[ProcessChunkJob N]
    end

    subgraph aggregation [Aggregation Phase]
        Aggregator[Results Aggregator]
    end

    ProcessBatchUploadJob --> S3StreamingReader
    S3StreamingReader --> Chunk1
    S3StreamingReader --> Chunk2
    S3StreamingReader --> Chunk3
    S3StreamingReader --> ChunkN

    Chunk1 --> Aggregator
    Chunk2 --> Aggregator
    Chunk3 --> Aggregator
    ChunkN --> Aggregator

    Aggregator --> FinalStatus[Update BatchUpload Status]
```

## Error Handling Strategy

| Error Type                  | Handling                                          | Retry    |
| --------------------------- | ------------------------------------------------- | -------- |
| **Schema Validation**       | Log to `batch_upload_errors`, continue processing | No       |
| **Business Rule Violation** | Log to `batch_upload_errors`, continue processing | No       |
| **Duplicate Record**        | Log as duplicate, skip record                     | No       |
| **Database Error**          | Retry chunk with exponential backoff              | Yes (3x) |
| **S3 Error**                | Retry job with exponential backoff                | Yes (5x) |
| **Unknown Error**           | Fail batch, log full stack trace                  | Manual   |

## Related Documents

- [C4 Context Diagram](./c4-context.md) - System context
- [C4 Container Diagram](./c4-container.md) - Container architecture
- [Architecture Decisions](./c4-decisions.md) - Key technical decisions
