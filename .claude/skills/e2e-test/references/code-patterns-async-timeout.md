# Async & Timeout Patterns

**Use this section during code generation to know when to add timeouts and waits.**

| Scenario | Pattern | Reason |
|----------|---------|--------|
| Simple form submit | `.click()` → `waitForURLtoMatchPagePath()` | Page redirect is instant |
| Form with email verification | `test.slow()` or `test.setTimeout(60000)` | Email service API call (5-30s) |
| Document upload | `setInputFiles()` → `waitForLoadState('networkidle')` → next page | File processing is async |
| Background job trigger | After submit: `await page.waitForLoadState('networkidle')` | Job may take 5-10s |
| External API call (DocAI, VA) | `test.slow()` or `test.setTimeout(120000)` | Depends on external service speed |
| Payment/financial transaction | `test.slow()` | Bank/payment API likely slow |

## When NOT to add extra waits

- Simple text entry + button click with instant page redirect → use only `waitForURLtoMatchPagePath()`
- Form validation errors (client-side) → form stays on same page, no wait needed

## Timeout values

- **Default**: 30 seconds per page action
- **`test.slow()`**: 3× default (90 seconds) — for flows with known API delays
- **`test.setTimeout(N)`**: Override to N milliseconds (e.g., 120000 for 2 minutes)

## Usage in tests

```typescript
import { test } from '../../fixtures';

// For flows with API delays (email verification, DocAI, etc.)
test('member submits activity report with document upload', async ({ page }) => {
  test.slow(); // 90-second timeout for DocAI processing
  // ... test code ...
});

// For specific timeout override
test('member submits payment', async ({ page }) => {
  test.setTimeout(120000); // 2 minutes for bank API
  // ... test code ...
});

// For simple flows (no special timeout needed)
test('member fills form and submits', async ({ page }) => {
  // Default 30-second timeout applies
  // ... test code ...
});
```
