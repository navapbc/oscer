# Architecture

## Key directories

| Path | Purpose |
|------|---------|
| `app/adapters/` | External service integrations (auth, storage, VA API, DocAI) |
| `app/business_processes/` | Workflow orchestration (`Strata::BusinessProcess`) |
| `app/forms/` | Form objects for multi-step/non-AR forms |
| `app/policies/` | Pundit authorization (`ApplicationPolicy` defaults all to false) |
| `app/services/` | Domain services; receive adapters as constructor args |
| `app/components/` | ViewComponent reusable UI components |
| `app/jobs/` | GoodJob (PostgreSQL-backed) background jobs |
| `app/helpers/` | View helpers including `UswdsFormBuilder` |
| `app/mailers/` | Email classes (`MemberMailer`) via AWS SES |
| `app/types/` | Custom ActiveAttribute types (`ArrayType`, `EnumType`) |
| `app/javascript/controllers/` | Stimulus controllers (Hotwire interactivity) |
| `app/models/rules/` | Business rules engines (e.g., `ExemptionRuleset`) |
| `app/models/api/` | API request/response value objects |
| `app/models/certifications/` | Certification sub-domain models (requirements, member data) |
| `app/controllers/api/` | API endpoints (certifications, batch uploads, health, direct uploads) |
| `app/controllers/auth/` | Auth callbacks (Member OIDC, Staff SSO) |
| `app/controllers/staff/` | Staff-facing controllers (dashboard, users, batch uploads) |
| `lib/middleware/` | Custom Rack middleware (`ApiErrorResponse`) |
| `lib/active_model/` | Custom validators and attribute types |

## Controller namespaces

| Namespace | Purpose |
|-----------|---------|
| Root | Member-facing: activities, exemptions, document staging, dashboard, certifications |
| `Api::` | JSON API: certifications, batch uploads, health check, direct uploads (HMAC auth) |
| `Auth::` | OAuth callbacks: `MemberOidcController`, `SsoController` |
| `Staff::` | Staff portal: dashboard, users, certification batch uploads |
| `Users::` | Devise overrides: sessions, registrations, MFA, passwords, accounts |
| `Demo::` | Demo tools for certification creation |

## Background jobs

GoodJob (PostgreSQL-backed) for async processing. Admin dashboard at `/good_job` (admin-only).

Key jobs:
- `FetchDocAiResultsJob` – polls DocAI for document processing results
- `ProcessCertificationBatchUploadJob` / `ProcessCertificationBatchChunkJob` – async batch import with chunked processing
- `PurgeUnattachedBlobsJob` – Active Storage cleanup

## API layer

JSON API under `/api/` namespace with HMAC authentication (`ApiHmacAuthentication` concern). OpenAPI docs generated via OAS Rails gem at `/api/docs`. Generate spec: `make openapi-spec`.
