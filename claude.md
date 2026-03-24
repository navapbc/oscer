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

### Bounded contexts

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

### Key directories

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

### Controller namespaces

| Namespace | Purpose |
|-----------|---------|
| Root | Member-facing: activities, exemptions, document staging, dashboard, certifications |
| `Api::` | JSON API: certifications, batch uploads, health check, direct uploads (HMAC auth) |
| `Auth::` | OAuth callbacks: `MemberOidcController`, `SsoController` |
| `Staff::` | Staff portal: dashboard, users, certification batch uploads |
| `Users::` | Devise overrides: sessions, registrations, MFA, passwords, accounts |
| `Demo::` | Demo tools for certification creation |

### Feature flags

Environment-variable-based feature flags via `Features` module (`config/initializers/feature_flags.rb`):

```ruby
Features.doc_ai_enabled?         # FEATURE_DOC_AI env var
Features.enabled?(:doc_ai)       # Generic check
```

Test helpers: `with_doc_ai_enabled { ... }` / `with_doc_ai_disabled { ... }`

To add a flag, add an entry to `Features::FEATURE_FLAGS` hash — methods and test helpers are auto-generated.

### Strata SDK

The `strata` gem provides government forms infrastructure. Key base classes:
- `Strata::Case` – extended by `CertificationCase`
- `Strata::Task` – extended by `OscerTask`, `ReviewActivityReportTask`, `ReviewExemptionClaimTask`
- `Strata::BusinessProcess` – extended by `CertificationBusinessProcess`
- `Strata::ValueObject` – extended by `Member`
- `Strata::EventManager` – pub/sub for domain events (registered in `config/application.rb`)

> **IMPORTANT**: Before writing any code that uses Strata classes, **always read the relevant files in `.claude/references/strata-sdk-rails/`** for authoritative documentation, method signatures, and usage examples. Do not rely on assumptions about the Strata API.

## Critical implementation details

### UUID primary keys

All tables use UUIDs, not integer primary keys.

- **Never use** `Model.first` or `Model.last` — results are unreliable with UUIDs
- **Always pass** `--primary-key-type=uuid` when generating models/scaffolds
- `make db-reset` recreates from `db/schema.rb`, not migrations

### Strict loading

Strict loading is enabled by default (`config.active_record.strict_loading_by_default = true`). In request specs, use `.user_id` instead of `.user` to avoid `StrictLoadingViolationError`.

### Authorization (Pundit)

`ApplicationController` has `after_action` hooks that raise if authorization is skipped:
- Forgetting `authorize @resource` → `AuthorizationNotPerformedError`
- Forgetting `policy_scope(Resource)` → `PolicyScopingNotPerformedError`

To opt out in actions that don't need them:
```ruby
skip_after_action :verify_authorized
skip_after_action :verify_policy_scoped
# or per-action:
skip_authorization
skip_policy_scope
```

Headless policies (no record): `authorize :symbol, :action?`

### Authentication

**Triple auth system:**
- **Members (form)**: Devise + Auth adapter (Cognito in prod, Mock in dev/test)
- **Members (OIDC)**: `Auth::MemberOidcController` → `MemberOidcProvisioner` (SSO for members)
- **Staff**: OmniAuth OIDC SSO → `StaffUserProvisioner` → role mapping via `config/sso_role_mapping.yml`
- **API**: HMAC authentication via `ApiHmacAuthentication` concern

**Mock adapter triggers** (dev/test with `AUTH_ADAPTER=mock`):

| Scenario | Trigger |
|----------|---------|
| Unconfirmed account | Email contains `unconfirmed` |
| Invalid credentials | Password is `wrong` |
| MFA challenge | Email contains `mfa` |
| Successful login | Any other email/password |

### USWDS forms

Use `us_form_with` instead of `form_with` for all views. It applies USWDS styling automatically:

```erb
<%= us_form_with model: @form do |f| %>
  <%= f.text_field :name, { hint: t(".name.hint") } %>
  <%= f.yes_no :has_previous_leave %>
  <%= f.fieldset t(".type_legend") do %>
    <%= f.radio_button :type, "medical" %>
  <% end %>
  <%= f.submit %>
<% end %>
```

### Internationalization

- Locales: English and Spanish (`es-US`)
- Routes are localized via `route_translator`
- All user-facing strings must go in `config/locales/`
- View-specific keys use nested paths matching the view file path
- Generate locale files: `make locale`

### Background jobs

GoodJob (PostgreSQL-backed) for async processing. Admin dashboard at `/good_job` (admin-only).

Key jobs:
- `FetchDocAiResultsJob` – polls DocAI for document processing results
- `ProcessCertificationBatchUploadJob` / `ProcessCertificationBatchChunkJob` – async batch import with chunked processing
- `PurgeUnattachedBlobsJob` – Active Storage cleanup

### API layer

JSON API under `/api/` namespace with HMAC authentication (`ApiHmacAuthentication` concern). OpenAPI docs generated via OAS Rails gem at `/api/docs`. Generate spec: `make openapi-spec`.

## Testing

- **Framework**: RSpec 8.0; **Coverage**: 92% line / 70% branch minimum
- **Run a single spec**: `make test args="spec/models/certification_spec.rb"`
- Adapters are swappable — inject mock adapters in tests, not real external services
- Test coverage enforced by SimpleCov; CI will fail below thresholds
- Feature flag test helpers: `with_<flag>_enabled` / `with_<flag>_disabled`
- `instance_double(ActiveStorage::Attached::One)` doesn't work for `blob` — use `double` with rubocop disable comment

### E2E tests

Playwright end-to-end tests live in `e2e/` (TypeScript). Page Object pattern with flow fixtures:
- **To create a new e2e test:** Use the `/e2e-test` skill. It guides you through planning (with plan mode approval), live app exploration via Playwright MCP, code generation, and two-phase validation (CLI test + localhost walkthrough).

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
