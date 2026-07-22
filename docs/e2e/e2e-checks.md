# End-to-End (E2E) Tests

## Overview

This repository uses [Playwright](https://playwright.dev/) to perform end-to-end (E2E) tests. The tests can be run locally (natively or within Docker), but they also run on [Pull Request preview environments](/docs/infra/pull-request-environments.md). This ensures that any new code changes are validated through E2E tests before being merged.

By default in CI, tests are sharded across 3 concurrent runs to reduce total runtime. As the test suite grows, consider increasing the shard count to further optimize execution time. This is set in the [workflow file](../../.github/workflows/e2e-tests.yml#L22).

## Folder Structure
In order to support e2e for multiple apps, the folder structure will include a base playwright config (`/e2e/playwright.config.js`), and app-specific derived playwright config that override the base config. This project's folder structure:
```
e2e/
  playwright.config.js
  reporting-app/
    playwright.config.js
    tests/
      *.spec.ts
```

Some highlights:
>- By default, the base config is defined to run on a minimal browser-set (desktop and mobile chrome). Browsers can be added in the app-specific playwright config.
>- Snapshots will be output locally (in the `/e2e` folder or the container) - or in the artifacts of the CI job
>- HTML reports are output to the `playwright-report` folder
>- Accessibility testing can be performed using the `@axe-core/playwright` package (https://playwright.dev/docs/accessibility-testing)

## Run tests locally

> **All E2E `make` targets live in the root `Makefile` and must be run from the repository root**, not from `reporting-app/`. The `e2e/` directory is a sibling of `reporting-app/`.

### Prerequisites

1. **The application must be running** at `http://localhost:3000`. See [Getting Started](../how-to-guides/getting-started.md).
2. **Auth adapter must be `cognito`** in `reporting-app/.env`. The mock adapter (`AUTH_ADAPTER=mock`) advances past registration but cannot deliver verification emails, so every auth-gated test will hang for ~3 minutes per test. See [Authentication](../reporting-app/auth.md#cognito-adapter-production-e2e) for the AWS prerequisites (provisioned IAM user, AWS CLI configured locally, user pool ID, client ID, and client secret).
3. **DocAI must be configured and enabled** in `reporting-app/.env`. E2E flows that exercise document staging and activity pre-fill depend on the DocAI service. See [Configuring DocAI](../how-to-guides/configuring-doc-ai.md) for the full variable set and feature-flag toggle.
4. **Set `SKIP_PUBLIC_REQUEST_HOST=true`** on the Rails process. Uncomment the line in `reporting-app/.env`:
   ```bash
   SKIP_PUBLIC_REQUEST_HOST=true
   ```
   Without this, Rails redirects rewrite to `APP_HOST` and Playwright (which talks to `host.docker.internal` or another origin) lands on a different host mid-test. Omit this only in real deployments where canonical-host rewriting is intended.

### Run the suite in Docker (preferred)

From the repository root:

```bash
make e2e-test APP_NAME=reporting-app BASE_URL=http://host.docker.internal:3000
```

> `BASE_URL` cannot be `localhost` when running in Docker, because the e2e container reaches the host via `host.docker.internal`.

### Run the suite natively

First install Playwright (one time):

```bash
make e2e-setup
```

Then run:

```bash
make e2e-test-native APP_NAME=reporting-app
```

> `BASE_URL` is optional for `e2e-test-native` and `e2e-test-native-ui`; it defaults to the `baseURL` in `e2e/reporting-app/playwright.config.js` (`http://localhost:3000`).

### Run a single test

Pass the spec path via `E2E_ARGS`. Paths are relative to `e2e/`.

```bash
# Docker
make e2e-test APP_NAME=reporting-app BASE_URL=http://host.docker.internal:3000 \
  E2E_ARGS=reporting-app/tests/exemptionApplication.spec.ts

# Native
make e2e-test-native APP_NAME=reporting-app \
  E2E_ARGS=reporting-app/tests/exemptionApplication.spec.ts
```

### Performance baselines (frontier / low-bandwidth)

Client-facing performance harnesses for [OSCER-747](https://github.com/navapbc/oscer/issues/747) live under `e2e/reporting-app/perf/` and these opt-in specs:

| Spec | Purpose |
| --- | --- |
| `performanceBaseline.spec.ts` (Track A) | CDP throttling (DevTools Slow/Fast 3G), writes `e2e/perf-results/perf-baseline.json` + `.md` |
| `performanceBaselineFlow.spec.ts` | Multi-step flows under the same profiles: (1) all-No screener → 2 hours + income with supporting docs; (2) medical exemption Yes + upload. Writes `perf-baseline-flow-*.json/.md`. **Very slow** (tens of minutes–1h+ for all profiles). |
| `lighthouseBudget.spec.ts` (Track B) | Lighthouse over CDP; writes reports under `e2e/perf-results/lighthouse/` |

These specs are **excluded from the default e2e suite and CI** unless `PERF=1`. The GitHub Actions e2e workflow does **not** set `PERF`, so they never run in CI. Run them **locally only** (app must be up; same Cognito prerequisites as other member tests):

```bash
# Track A — capture page baselines (chromium only; minutes, not hours)
make e2e-perf-baseline APP_NAME=reporting-app

# Optional: subset of profiles / output dir
PERF_PROFILES="Slow 3G" make e2e-perf-baseline APP_NAME=reporting-app

# Multi-step flows — LONG-RUNNING; prefer one profile first
# WARNING: all three profiles can take tens of minutes to 1+ hour. Not for CI.
# Make forces --workers=1; each profile clears cookies before creating a new member.
PERF_PROFILES="Slow 3G" make e2e-perf-baseline-flow APP_NAME=reporting-app
make e2e-perf-baseline-flow APP_NAME=reporting-app

# Track B — Lighthouse reports (chromium, workers=1 for fixed CDP port 9222)
make e2e-perf-lighthouse APP_NAME=reporting-app

# After baselines are calibrated, enforce budget.json + score floors:
PERF_ENFORCE_BUDGET=1 make e2e-perf-lighthouse APP_NAME=reporting-app
```

Equivalent with Docker (also mounts `e2e/perf-results/`):

```bash
make e2e-test APP_NAME=reporting-app BASE_URL=http://host.docker.internal:3000 PERF=1 \
  E2E_ARGS='reporting-app/tests/performanceBaseline.spec.ts --project=chromium'
```

**Notes**

- Track A uses CDP `Network.emulateNetworkConditions` with Chrome DevTools Slow/Fast 3G constants.
- Flow baselines sum per-step wall-clock (`stepDurationMs`) for multi-step member walks; prefer `PERF_PROFILES="Slow 3G"` first. Results are gitignored under `e2e/perf-results/`—copy elsewhere to retain.
- Track B uses Lighthouse `throttlingMethod: 'simulate'` with settings *derived from* Slow 3G. Simulated timings are **not** 1:1 comparable to Track A / DevTools.
- Default Track B is capture-first (reports only). `PERF_ENFORCE_BUDGET=1` turns on `lighthouse/budget.json` and category thresholds.
- Env vars: `PERF`, `PERF_PROFILES`, `PERF_OUT_DIR`, `PERF_ENFORCE_BUDGET`.

**Example local capture (illustrative; re-run for current numbers):** On Slow 3G, Track A cold FCP was ~7.5–10s on ~400 KB pages; the activities flow summed to ~7.7 minutes of measured steps and the medical exemption flow ~2.5 minutes (small fixture uploads ~20–23s).

### Run tests in UI mode (native)

```bash
make e2e-test-native-ui APP_NAME=reporting-app
```

#### Run tests in parallel

The following commands split test execution into 3 separate shards, with results consolidated into a merged report located in `/e2e/blob-report`. This setup emulates how the sharded tests run in CI.

```
# ensure app is running on port 3000

make e2e-test APP_NAME=reporting-app BASE_URL=http://host.docker.internal:3000 TOTAL_SHARDS=3 CURRENT_SHARD=1 CI=true && \
make e2e-test APP_NAME=reporting-app BASE_URL=http://host.docker.internal:3000 TOTAL_SHARDS=3 CURRENT_SHARD=2 CI=true && \
make e2e-test APP_NAME=reporting-app BASE_URL=http://host.docker.internal:3000 TOTAL_SHARDS=3 CURRENT_SHARD=3 CI=true

make e2e-merge-reports REPORT_PATH=blob-report # merge the blob reports into html
make e2e-show-report # open the html report in browser
make e2e-clean-report # clean the report folders
```

### Viewing the report
If running in docker, the report will be copied from the container to your local `/e2e/playwright-report` folder. If running natively, the report will also appear in this same folder.

To quickly view the report, you can run:

```bash
make e2e-show-report
```

To clean the report folder you can run:

```bash
make e2e-clean-report
```

>*On CI, the report shows up in the GitHub Actions artifacts tab


### PR preview environments

The E2E tests are triggered in PR preview environments on each PR update. For more information on how PR environments work, please refer to [PR Environments Documentation](/docs/infra/pull-request-environments.md).

For **reporting-app**, preview ECS tasks set **`SKIP_PUBLIC_REQUEST_HOST=true`** in Terraform (`infra/reporting-app/service/main.tf`) because Playwright uses the load-balancer `service_endpoint` while **`APP_HOST`** stays the environment’s configured domain for OIDC—so you do not set this in the GitHub Actions workflow itself.

### Workflows

The following workflows trigger E2E tests:
- [PR Environment Update](../../.github/workflows/pr-environment-checks.yml)
- [E2E Tests Workflow](../../.github/workflows/e2e-tests.yml)

The [E2E Tests Workflow](../../.github/workflows/e2e-tests.yml) takes a `service_endpoint` URL and an `app_name` to run the tests against specific configurations for your app.

## Configuration

The E2E tests are configured using the following files:
- Base Configuration in `/e2e/playwright.config.js`
- App-specific Configuration in `/e2e/<APP_NAME>/playwright.config.js`

The app-specific configuration files extend the common base configuration.

`BASE_URL` is optional for native runs because the app-specific config (`/e2e/<APP_NAME>/playwright.config.js`) provides a default. In Docker, `BASE_URL` is required and must use a host the container can reach (typically `http://host.docker.internal:3000`).
