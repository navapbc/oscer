# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository structure

The Rails application lives in `reporting-app/`. **All `make` commands below must be run from that subdirectory**, not the repo root.

```
reporting-app/    # Rails 7.2 app (Ruby 3.4.7)
infra/            # Terraform infrastructure
e2e/              # Playwright end-to-end tests (TypeScript)
docs/             # Architecture & feature docs
  architecture/   # Feature-specific ADRs (batch-upload, doc-ai, staff-sso, va-eligibility, etc.)
  reporting-app/  # App-level docs (auth, forms, i18n, security, jobs, lookbook)
```

## Commands

```bash
# Development
make start-native          # Run app locally (Procfile.dev)
make start-container       # Run via Docker
make init-native           # First-time setup (native)
make rails-console         # Rails console
make rails-routes          # Show all routes
make clear-cache           # Clear Rails cache and assets
make precompile-assets     # Precompile asset pipeline

# Testing
make test                             # Full test suite
make test args="spec/path/to/file.rb" # Single file

# Database
make db-migrate        # Run pending migrations
make db-rollback       # Rollback last migration
make db-seed           # Seed data
make db-reset          # Drop, recreate from schema.rb, reseed
make db-test-prepare   # Prepare test database
make db-up             # Start just the database container
make db-console        # PostgreSQL console

# Code generation (always pass --primary-key-type=uuid)
make rails-generate GENERATE_COMMAND="model Foo --primary-key-type=uuid"
make rails-generate GENERATE_COMMAND="migration AddColumnToFoos column:type"
make rails-generate GENERATE_COMMAND="scaffold Foo --primary-key-type=uuid"

# Locales & authorization
make locale                          # Generate locale files for a model
make new-authz-policy MODEL=Foo      # Generate Pundit policy

# API documentation
make openapi-spec      # Generate OpenAPI YAML spec

# Code quality
make lint       # RuboCop with auto-fix
```

## Bounded contexts

- **Certifications** – `Certification` (aggregate root) → `CertificationCase` → `Activities`, `InformationRequests`, `Determination`
- **Certification Batch Uploads** – `CertificationBatchUpload` → `CertificationBatchUploadAuditLog`, `CertificationBatchUploadError`; async chunked processing via GoodJob
- **Activity Reporting** – `ActivityReportApplicationForm` → `Activity` (STI: `HourlyActivity`, `IncomeActivity`, `WorkActivity`, `ExPartActivity`) → `ActivityReportInformationRequest`
- **Exemptions** – `ExemptionApplicationForm` → `Exemption` → `ExemptionInformationRequest`; rules engine via `Rules::ExemptionRuleset`
- **Document AI (DocAI)** – `StagedDocument` (pending → validated → rejected → failed) → `DocAiResult` (value object with `Payslip` subclass); confidence scoring, payslip-to-activity pre-fill. Feature-flagged via `FEATURE_DOC_AI`
- **Ex Parte Activities** – `ExPartActivity` with source tracking (batch upload vs. API); imported via batch or VA integration
- **Tasks** – `OscerTask` (extends `Strata::Task`), `ReviewActivityReportTask`, `ReviewExemptionClaimTask` – polymorphic work items for staff
- **Auth** – `User` (Devise) with triple login: member form, member OIDC (`MemberOidcController`), staff SSO (`Auth::SsoController`)
- **VA Integration** – `VeteranAffairsAdapter` → `VeteranDisabilityService` for eligibility/disability data
- **Notifications** – `NotificationService` + `NotificationsEventListener` (event-driven via Strata pub/sub) → `MemberMailer` (AWS SES)

## Development workflow

1. **Ask clarifying questions** before writing code — never assume business logic
2. **Write RSpec tests first**, present for approval, then implement
3. After passing tests: `make lint` then `make test`

## Reference files

- `reporting-app/db/schema.rb` — authoritative DB structure
- `docs/reporting-app/software-architecture.md` — architecture patterns
- `docs/reporting-app/auth.md` — auth details
- `docs/reporting-app/forms.md` — USWDS form helper reference
- `docs/reporting-app/internationalization.md` — i18n conventions
- `docs/reporting-app/background-jobs.md` — GoodJob configuration
- `docs/reporting-app/api.md` — API documentation
- `docs/reporting-app/application-security.md` — security practices
- `docs/reporting-app/lookbook.md` — ViewComponent preview reference
- `docs/architecture/doc-ai-integration/` — DocAI API specifications
- `docs/architecture/batch-upload/` — Batch upload architecture
- `docs/architecture/staff-sso/` — SSO implementation details
- `docs/architecture/va-eligibility-integration/` — VA integration specs
- `docs/feature-flags.md` — Feature flag documentation
