# C4 Level 2: Container Diagram

## Batch Upload System - Container Architecture

This document describes the containers (deployable units) that make up the Batch Upload System and their interactions.

## Container Diagram

```mermaid
flowchart TB
    Staff[Staff User]
    
    subgraph system [Batch Upload System]
        WebApp[Web Application - Rails 7]
        Workers[Background Workers - Sidekiq]
        Postgres[(PostgreSQL)]
        Redis[(Redis)]
    end
    
    subgraph external [External Services]
        S3[(AWS S3)]
        APM[Datadog]
    end
    
    Staff -->|"HTTPS"| WebApp
    WebApp -->|"ActiveRecord"| Postgres
    WebApp -->|"Enqueue jobs"| Redis
    WebApp -->|"Presigned URLs"| S3
    
    Workers -->|"ActiveRecord"| Postgres
    Workers -->|"Stream files"| S3
    Workers -->|"Dequeue jobs"| Redis
    Workers -->|"Metrics"| APM
    WebApp -->|"Metrics"| APM
```

## Containers

### Web Application (Rails)

| Attribute | Value |
|-----------|-------|
| **Technology** | Ruby on Rails 7 |
| **Responsibilities** | HTTP request handling, UI rendering, API endpoints, presigned URL generation |
| **Scaling** | Horizontal (multiple Puma workers) |

**Key Endpoints:**
- `POST /staff/batch_uploads/presigned_url` - Generate S3 presigned URL for direct upload
- `POST /staff/batch_uploads` - Register upload and enqueue processing
- `GET /staff/batch_uploads/:id` - View upload status and metrics
- `POST /api/v1/batch_uploads` - External API for automated uploads

### Background Workers

| Attribute | Value |
|-----------|-------|
| **Technology** | Sidekiq or GoodJob |
| **Responsibilities** | Streaming file processing, chunk processing, audit logging, error handling |
| **Scaling** | Horizontal (multiple worker processes/pods) |

**Key Jobs:**
- `ProcessBatchUploadJob` - Orchestrates the overall processing
- `ProcessChunkJob` - Processes a chunk of records
- `SyncFtpFilesJob` - Syncs files from FTP to S3 (scheduled)

### PostgreSQL Database

| Attribute | Value |
|-----------|-------|
| **Technology** | PostgreSQL 14+ |
| **Responsibilities** | Persistent storage for all application data |
| **Scaling** | Vertical + Read replicas |

**Key Tables for Batch Upload:**

```sql
-- Main batch upload tracking
batch_uploads (
    id, status, source_type, filename, s3_key,
    total_records, processed_records, succeeded_records, failed_records,
    started_at, completed_at, created_at
)

-- Aggregated audit events (not per-record)
batch_upload_audit_logs (
    id, batch_upload_id, event_type, chunk_number,
    records_in_chunk, succeeded_count, failed_count,
    duration_ms, metadata, created_at
)

-- Failed records only (for debugging/retry)
batch_upload_errors (
    id, batch_upload_id, row_number, error_code,
    error_message, row_data, created_at
)
```

### Redis (Cache/Queue)

| Attribute | Value |
|-----------|-------|
| **Technology** | Redis 7 |
| **Responsibilities** | Job queue, rate limiting, caching |
| **Scaling** | Redis Cluster or ElastiCache |

**Usage:**
- Job queue for Sidekiq/GoodJob
- Rate limiting for API endpoints
- Caching of dashboard metrics

### AWS S3 (External)

| Attribute | Value |
|-----------|-------|
| **Technology** | AWS S3 |
| **Responsibilities** | File storage for uploads |
| **Buckets** | `raw-uploads/`, `processed/`, `errors/` prefixes |

**Lifecycle Policies:**
- Raw uploads: Move to Glacier after 90 days
- Error exports: Delete after 30 days
- Processed files: Archive after processing

### Datadog (External)

| Attribute | Value |
|-----------|-------|
| **Technology** | Datadog APM |
| **Responsibilities** | Metrics, traces, alerting |

**Custom Metrics:**
- `batch_upload.records.processed` (counter)
- `batch_upload.records.failed` (counter)
- `batch_upload.processing.duration` (histogram)
- `batch_upload.chunk.size` (gauge)

## Communication Patterns

### Synchronous (Request/Response)

```mermaid
sequenceDiagram
    participant Client
    participant WebApp
    participant S3
    
    Client->>WebApp: POST /presigned_url
    WebApp->>S3: Generate presigned URL
    S3-->>WebApp: Presigned URL
    WebApp-->>Client: {url, upload_id, fields}
    
    Client->>S3: PUT file (direct upload)
    S3-->>Client: 200 OK
    
    Client->>WebApp: POST /batch_uploads (confirm)
    WebApp-->>Client: {id, status: pending}
```

### Asynchronous (Job Queue)

```mermaid
sequenceDiagram
    participant WebApp
    participant Redis
    participant Worker
    participant S3
    participant DB
    
    WebApp->>Redis: Enqueue ProcessBatchUploadJob
    Worker->>Redis: Dequeue job
    Worker->>S3: Stream file
    
    loop For each chunk
        Worker->>DB: Create audit log entry
        Worker->>DB: Process records
        Worker->>DB: Log errors (if any)
    end
    
    Worker->>DB: Update batch status
```

## Deployment Topology

```mermaid
flowchart TB
    subgraph vpc [AWS VPC]
        subgraph public [Public Subnet]
            ALB[Application Load Balancer]
        end
        
        subgraph private [Private Subnet]
            subgraph ecs [ECS Cluster]
                Web1[Web Container 1]
                Web2[Web Container 2]
                Worker1[Worker Container 1]
                Worker2[Worker Container 2]
            end
            
            RDS[(RDS PostgreSQL)]
            ElastiCache[(ElastiCache Redis)]
        end
    end
    
    S3[(S3 Buckets)]
    
    ALB --> Web1
    ALB --> Web2
    Web1 --> RDS
    Web2 --> RDS
    Worker1 --> RDS
    Worker2 --> RDS
    Web1 --> ElastiCache
    Worker1 --> ElastiCache
    Worker1 --> S3
    Worker2 --> S3
```

## Related Documents

- [C4 Context Diagram](./c4-context.md) - System context
- [C4 Component Diagram](./c4-component.md) - Detailed component breakdown
- [Architecture Decisions](./c4-decisions.md) - Key technical decisions

