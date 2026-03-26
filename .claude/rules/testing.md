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

### Dev server

- Default URL: `http://localhost:3000`
- Start: `make start-container` (Docker) or `make start-native` (native Ruby)
- If app image needs rebuild first: `make build`

### Running tests

```bash
cd oscer/e2e
APP_NAME=reporting-app npx playwright test reporting-app/tests/<filename>.spec.ts
```

### Directory layout

```
e2e/reporting-app/
  tests/        ← spec files (<name>.spec.ts)
  pages/        ← Page Object classes (<dir>/<Name>Page.ts)
  flows/        ← Flow orchestrators (<Name>Flow.ts) for 5+ step sequences
```

### Page Object conventions

- Extend `BasePage`; define abstract `pagePath` getter (use `*` for dynamic segments)
- Declare all locators as `readonly Locator` properties in the constructor
- Each method returns the next page object (enables chaining)
- File uploads: always use `page.locator('input[type="file"]')` in the Page Object

### USWDS patterns

- CSS-hidden radio/checkbox inputs (USWDS default): use `.dispatchEvent('click')` instead of `.click()`
- Target label text for hidden inputs: `getByLabel('Option label')`

### Barrel exports (REQUIRED)

Every new `.ts` file must be exported from its barrel `index.ts`, or imports will fail at runtime:

```typescript
// pages/members/index.ts — add new page
export { NewPageName } from './NewPageName';

// flows/index.ts — add new flow
export { NewFlowName } from './NewFlowName';
```

Before validation, verify:
- Every new file has a corresponding export in its barrel `index.ts`
- Test imports use the barrel: `import { NewPage } from '../pages'`
