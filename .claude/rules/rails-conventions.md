# Rails Conventions

## UUID primary keys

All tables use UUIDs, not integer primary keys.

- **Never use** `Model.first` or `Model.last` — results are unreliable with UUIDs
- **Always pass** `--primary-key-type=uuid` when generating models/scaffolds
- `make db-reset` recreates from `db/schema.rb`, not migrations

## Strict loading

Strict loading is enabled by default (`config.active_record.strict_loading_by_default = true`). In request specs, use `.user_id` instead of `.user` to avoid `StrictLoadingViolationError`.

## Authorization (Pundit)

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

## Feature flags

Environment-variable-based feature flags via `Features` module (`config/initializers/feature_flags.rb`):

```ruby
Features.doc_ai_enabled?         # FEATURE_DOC_AI env var
Features.enabled?(:doc_ai)       # Generic check
```

Test helpers: `with_doc_ai_enabled { ... }` / `with_doc_ai_disabled { ... }`

To add a flag, add an entry to `Features::FEATURE_FLAGS` hash — methods and test helpers are auto-generated.

## Strata SDK

The `strata` gem provides government forms infrastructure. Key base classes:
- `Strata::Case` – extended by `CertificationCase`
- `Strata::Task` – extended by `OscerTask`, `ReviewActivityReportTask`, `ReviewExemptionClaimTask`
- `Strata::BusinessProcess` – extended by `CertificationBusinessProcess`
- `Strata::ValueObject` – extended by `Member`
- `Strata::EventManager` – pub/sub for domain events (registered in `config/application.rb`)

> **IMPORTANT**: Before writing any code that uses Strata classes, **always read the relevant files in `.claude/references/strata-sdk-rails/`** for authoritative documentation, method signatures, and usage examples. Do not rely on assumptions about the Strata API.
