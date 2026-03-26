# Testing

- **Framework**: RSpec 8.0; **Coverage**: 92% line / 70% branch minimum
- **Run a single spec**: `make test args="spec/models/certification_spec.rb"`
- Adapters are swappable — inject mock adapters in tests, not real external services
- Test coverage enforced by SimpleCov; CI will fail below thresholds
- Feature flag test helpers: `with_<flag>_enabled` / `with_<flag>_disabled`
- `instance_double(ActiveStorage::Attached::One)` doesn't work for `blob` — use `double` with rubocop disable comment

## E2E tests

Playwright end-to-end tests live in `e2e/` (TypeScript). Page Object pattern with flow fixtures:
- **To create a new e2e test:** Use the `/e2e-test` skill. It guides you through planning (with plan mode approval), live app exploration via Playwright MCP, code generation, and two-phase validation (CLI test + localhost walkthrough).
- **File Uploads:** When uploading a file, always use the selector `this.fileInput = page.locator('input[type="file"]');` in the Page Object.
