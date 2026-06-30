# Configuration & operations reference

This doc covers OSCER's **application-specific** configuration (environment
variables) and the **operational notes** specific to running OSCER. It is an
addendum, not a deployment guide:

- For standing up infrastructure from zero (Terraform layers, CI/CD, PR
  environments), follow [`navapbc/template-infra`](https://github.com/navapbc/template-infra)'s
  own docs. This page does not restate them.
- For non-env-var customization (exemption types, feature flags, locales and
  branding), see [`CUSTOMIZATION.md`](../../reporting-app/CUSTOMIZATION.md).
- Generic Rails / infrastructure variables (`DB_*`, `RAILS_*`, `PORT`) are not
  listed here; they behave as in any Rails app.

OSCER is designed to be platform-agnostic; its reference deployment runs on AWS
via `template-infra`. Where a detail below is platform-specific it is marked
**AWS (reference deployment)**, and the underlying requirement (object storage,
a PostgreSQL database, email delivery, container log aggregation) is general:
a non-AWS deployment supplies its own equivalent.

In the tables below, **Requirement** is either a concrete default (the value
OSCER uses when the variable is unset) or "**Required**" (OSCER has no usable
default and a deployment must set it, sometimes only when a feature is enabled).

## Application host

These drive the `PublicRequestHost` middleware (canonical public host rewriting)
and the OIDC redirect-URI builder. Setting `APP_HOST` wrong, or leaving it
unset, produces broken OIDC callback URLs, so they matter beyond generic Rails
host config.

| Variable | Requirement | Notes |
| --- | --- | --- |
| `APP_HOST` | Default: `localhost` | Canonical public host for the deployment; used to build OIDC callback URLs. Set to your real domain. |
| `APP_PORT` | Default: `443` | Public port. Local dev typically overrides to `3000`. |
| `DISABLE_HTTPS` | Default: `false` | Set `true` only for local/non-TLS environments; controls the scheme in generated URLs. |

## Authentication

OSCER has a triple auth system; see [`auth.md`](auth.md) for how these fit
together. The variables below are the deployment-facing knobs. **AWS (reference
deployment):** Cognito is the reference backend for member form login; staff SSO
and member OIDC are provider-agnostic (any OIDC-compatible identity service).

| Variable | Requirement | Notes |
| --- | --- | --- |
| `AUTH_ADAPTER` | Default: `cognito` | Member form login backend. `cognito` in real environments; `mock` for local dev/test (any email/password logs in). |
| `COGNITO_USER_POOL_ID` | Required (when `AUTH_ADAPTER=cognito`) | Cognito user pool. |
| `COGNITO_CLIENT_ID` | Required (when `AUTH_ADAPTER=cognito`) | Cognito app client. |
| `COGNITO_CLIENT_SECRET` | Required (when `AUTH_ADAPTER=cognito`) | Cognito app client secret. |

### Staff SSO (OmniAuth OIDC)

| Variable | Requirement | Notes |
| --- | --- | --- |
| `SSO_ENABLED` | Default: `false` | Shows the SSO option on the sign-in page. |
| `SSO_ISSUER_URL` | Required (when `SSO_ENABLED=true`) | OIDC issuer; discovery is automatic. |
| `SSO_CLIENT_ID` | Required (when `SSO_ENABLED=true`) | |
| `SSO_CLIENT_SECRET` | Required (when `SSO_ENABLED=true`) | |
| `SSO_SCOPES` | Default: `openid profile email` | |
| `SSO_CLAIM_EMAIL` | Default: `email` | Claim name overrides for non-standard IdPs. |
| `SSO_CLAIM_NAME` | Default: `name` | |
| `SSO_CLAIM_GROUPS` | Default: `groups` | Drives staff role mapping (`config/sso_role_mapping.yml`). |
| `SSO_CLAIM_UID` | Default: `sub` | |
| `SSO_CLAIM_REGION` | Default: `custom:region` | |

### Member OIDC

| Variable | Requirement | Notes |
| --- | --- | --- |
| `MEMBER_OIDC_ENABLED` | Default: `false` | Enables member SSO via OIDC. |
| `MEMBER_OIDC_ISSUER_URL` | Required (when `MEMBER_OIDC_ENABLED=true`) | |
| `MEMBER_OIDC_CLIENT_ID` | Required (when `MEMBER_OIDC_ENABLED=true`) | |
| `MEMBER_OIDC_CLIENT_SECRET` | Required (when `MEMBER_OIDC_ENABLED=true`) | |
| `MEMBER_OIDC_SCOPES` | Default: `openid profile email` | |
| `MEMBER_OIDC_MEMBER_AUTH_ONLY` | Default: `false` | Restricts the provider to member auth only. |
| `MEMBER_OIDC_CLAIM_EMAIL` | Default: `email` | |
| `MEMBER_OIDC_CLAIM_NAME` | Default: `name` | |
| `MEMBER_OIDC_CLAIM_UID` | Default: `sub` | |

## File storage

OSCER stores uploads through a pluggable object-storage adapter; configure
exactly one. **AWS (reference deployment):** S3. Azure Blob Storage is also
supported.

> **Non-AWS note:** there are two storage paths. `STORAGE_ADAPTER` selects
> OSCER's custom adapter (env-switchable across `s3` / `azure`), but Rails
> Active Storage is configured separately and `config/environments/production.rb`
> pins it to AWS S3 (`config.active_storage.service = :amazon`). A non-AWS
> deployment must override that setting in `production.rb`, not just set
> `STORAGE_ADAPTER`.

| Variable | Requirement | Notes |
| --- | --- | --- |
| `STORAGE_ADAPTER` | Default: `s3` | Active Storage backend: `s3` or `azure`. |
| `BUCKET_NAME` | Required (when `STORAGE_ADAPTER=s3`) | S3 bucket for uploads. |
| `AWS_REGION` | Default: `us-east-1` | Region for the S3 client. |
| `AZURE_STORAGE_ACCOUNT` | Required (when `STORAGE_ADAPTER=azure`) | |
| `AZURE_STORAGE_ACCESS_KEY` | Required (when `STORAGE_ADAPTER=azure`) | |
| `AZURE_CONTAINER_NAME` | Required (when `STORAGE_ADAPTER=azure`) | |

## API

| Variable | Requirement | Notes |
| --- | --- | --- |
| `API_SECRET_KEY` | Required (to use the `/api/*` endpoints) | Shared secret for HMAC-SHA256 authentication on the JSON API. Unset means API requests cannot authenticate. See [api.md](api.md). |

## Email

OSCER sends member email via Action Mailer. **AWS (reference deployment):**
delivery goes through AWS SES; a non-AWS deployment substitutes its own delivery
method.

> **Non-AWS note:** `config/environments/production.rb` sets
> `config.action_mailer.delivery_method = :ses_v2`. A non-AWS deployment must
> override the delivery method in `production.rb` (e.g. SMTP or a provider
> gem); `AWS_SES_FROM_EMAIL` only sets the sender address, not the transport.

| Variable | Requirement | Notes |
| --- | --- | --- |
| `AWS_SES_FROM_EMAIL` | Required (for outbound member email) | Verified sender address. `SES_EMAIL` is accepted as a legacy alias. |

## Community-engagement policy

These encode program policy. Defaults reflect OSCER's shipped baseline; review
them against your program's requirements before going live.

| Variable | Requirement | Notes |
| --- | --- | --- |
| `CE_TARGET_MONTHLY_HOURS` | Default: `80` | Monthly hours threshold for the hours-based compliance pathway. |
| `CE_INCOME_THRESHOLD_MONTHLY` | Default: `580` | Monthly income threshold for the income-based compliance pathway. |
| `STATE_NAME` | Default: `the State` | Display name used in member-facing copy. |

## External integrations

### Veteran Affairs (disability rating)

| Variable | Requirement | Notes |
| --- | --- | --- |
| `VA_API_HOST` | Default: `https://sandbox-api.va.gov` | Points at the VA sandbox by default; set to the production host for real lookups. |
| `VA_TOKEN_HOST` | Default: `https://sandbox-api.va.gov/oauth2/veteran-verification/system/v1/token` | OAuth token endpoint; set to the production equivalent for real lookups. |
| `VA_TOKEN_AUDIENCE` | Default: `https://deptva-eval.okta.com/oauth2/ausi3u00gw66b9Ojk2p7/v1/token` | OAuth token audience. |
| `VA_CLIENT_ID_CCG` | Required (to use the VA integration) | Client-credentials-grant client ID; unset disables real lookups. |
| `VA_PRIVATE_KEY` | Required (to use the VA integration) | Signing key for the CCG flow. |

### Document AI (DocAI)

DocAI is also gated by the `FEATURE_DOC_AI` feature flag (see below).

| Variable | Requirement | Notes |
| --- | --- | --- |
| `DOC_AI_API_HOST` | Required (when DocAI is enabled) | DocAI service host. Not required at boot (defaults to unset), but DocAI calls fail at runtime if it's unset while DocAI is enabled. |
| `DOC_AI_TIMEOUT_SECONDS` | Default: `60` | |
| `DOC_AI_LOW_CONFIDENCE_THRESHOLD` | Default: `0.7` | Below this confidence, a result is treated as low-confidence. |

### Staged-document cleanup

This runs regardless of `FEATURE_DOC_AI`: the cleanup job is governed by
`STAGED_DOCUMENT_CLEANUP_ENABLED`, not the DocAI flag. (Staged documents are
created by the DocAI upload path, so there is simply nothing to clean when
DocAI is unused.)

| Variable | Requirement | Notes |
| --- | --- | --- |
| `STAGED_DOCUMENT_CLEANUP_ENABLED` | Default: `true` | Toggles the scheduled cleanup job. |
| `STAGED_DOCUMENT_RETENTION_DAYS` | Default: `7` | Age past which orphaned staged documents are purged. |
| `STAGED_DOCUMENT_CLEANUP_SCHEDULE` | Default: `0 2 * * *` | Cron schedule for the cleanup job. |

## Background jobs

See [`background-jobs.md`](background-jobs.md) for the full GoodJob setup.

| Variable | Requirement | Notes |
| --- | --- | --- |
| `GOOD_JOB_MAX_THREADS` | Default: `2` | Job threads. Kept below the Puma thread count to avoid exhausting the DB connection pool. |
| `GOOD_JOB_QUEUE_PREFIX` | Default: none, but **must be set when environments share a database** | Without it, environments sharing one database poll and run each other's jobs. The delimiter is `_`, not `:` (GoodJob parses `:` as a thread-count separator). **AWS (reference deployment):** Terraform sets it per ECS task (`local.service_name`). |

## Feature flags

OSCER-shipped built-in flags are environment-variable toggles. Deployments can
also define their own flags; see [`CUSTOMIZATION.md`](../../reporting-app/CUSTOMIZATION.md).

| Variable | Requirement | Notes |
| --- | --- | --- |
| `FEATURE_DOC_AI` | Default: `false` | Enables DocAI document analysis for income verification. |

## Operational notes

Notes specific to operating OSCER in a deployed environment.

### Use `./bin/rails` for container run-commands

When running one-off commands against a running container (migrations, console,
rake), invoke `./bin/rails ...`, not bare `rails`. The container entrypoint wraps
the process (tini), and the `./bin/rails` wrapper ensures the command runs with
the correct entrypoint setup. **AWS (reference deployment):** this applies to
ECS run-command / exec.

### Background-job execution model

By default OSCER runs GoodJob in `execution_mode = :async`, inside the Puma web
process, with no separate worker container (`config/initializers/good_job.rb`).
This is a deliberate simplification suited to **low-load environments (demo,
staging)**: one process to deploy and scale, no separate worker to operate.

Under this in-process default:

- **Web and job capacity scale together** — scaling the service scales both.
- **A job OOM takes down the web process,** since they share one process.
  `GOOD_JOB_MAX_THREADS` is kept below the Puma thread count so jobs don't
  exhaust the DB connection pool.
- **No automatic retry of unhandled errors** (`retry_on_unhandled_error =
  false`). A global zero-delay retry previously caused an OOM retry storm in
  production. Jobs that need retries declare their own bounded `retry_on`.

**For production / higher-load deployments, run GoodJob as a dedicated worker**
(its own process/container): set `execution_mode = :external` and run the
GoodJob worker (`bundle exec good_job start`) alongside the web process. This
decouples web and job scaling and isolates job memory pressure from web
availability. OSCER sets `:async` in `config/initializers/good_job.rb`, so
selecting `:external` is a change to that initializer.

The admin dashboard is at `/good_job` (admin-only).

### Database (PostgreSQL)

OSCER requires a PostgreSQL database. **AWS (reference deployment):** Aurora
Serverless Postgres, provisioned by `template-infra`'s database module; treat
its docs as authoritative for capacity, scaling, and connection configuration.
OSCER adds no workload-specific database tuning. Note the GoodJob-in-Puma
connection-pool sizing above when reasoning about connection limits.

### Logs

OSCER writes application logs to standard output via Rails logging;
`RAILS_LOG_LEVEL` controls verbosity. Log aggregation is the platform's
responsibility. **AWS (reference deployment):** logs land in CloudWatch under
the ECS service's log group per `template-infra`, with no OSCER-specific
deviation.

## See also

- [Authentication & Authorization](auth.md) — the triple auth system the auth variables configure.
- [Background jobs](background-jobs.md) — full GoodJob configuration.
- [Application security](application-security.md) — secrets handling and security practices.
- [API](api.md) — the HMAC-authenticated JSON API and its key handling.
- [`CUSTOMIZATION.md`](../../reporting-app/CUSTOMIZATION.md) — non-env-var configuration (exemption types, feature flags, locales, branding).
- [`navapbc/template-infra`](https://github.com/navapbc/template-infra) — authoritative deployment-from-zero docs.
