# Test File Template

**Location:** `e2e/reporting-app/tests/<name>.spec.ts`

## Full test file example

```typescript
import path from 'path'; // only if file fixtures needed
import { expect } from '@playwright/test';
import { test } from '../../fixtures'; // ALWAYS custom fixture, not base test
import {
  CertificationRequestPage,
  DashboardPage,
  NewPageName
} from '../pages'; // Import from barrel exports
import { AccountCreationFlow } from '../flows';

test('descriptive test name: what the user does and expects', async ({ page, emailService }) => {
  // Set timeout if test involves async operations (API calls, background jobs)
  // test.setTimeout(60000); // 60 seconds for slow operations
  // Or use test.slow() to triple the default (useful for external APIs, email verification)
  // test.slow();

  // Setup: Generate unique test data
  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';

  // Step 1: Certification request (if needed)
  const certPage = await new CertificationRequestPage(page).go();
  await certPage.fillAndSubmit(email);

  // Step 2: Account creation & sign-in
  const accountCreationFlow = new AccountCreationFlow(page, emailService);
  const signInPage = await accountCreationFlow.run(email, password);
  const mfaPage = await signInPage.signIn(email, password);
  await mfaPage.skipMFA();

  // Step 3: Feature-specific workflow
  const dashboardPage = new DashboardPage(page).waitForURLtoMatchPagePath();
  // ... continue flow steps ...

  // Final assertion: ALWAYS assert an observable outcome
  // Options:
  // - URL changed: expect(page.url()).toContain('/expected-path');
  // - Text visible: await expect(page.locator('h1')).toHaveText('Success Message');
  // - Element visible: await expect(page.locator('[data-testid="confirmation"]')).toBeVisible();
  // - Multiple assertions: chain them

  expect(page.url()).toContain('/dashboard');
  await expect(page.locator('h1')).toHaveText('Welcome');
});
```

## Requirements

- **ALWAYS use custom `test`** from `../../fixtures`, NOT base `@playwright/test`
- **Always assert the outcome** (URL change, text on page, element visibility, etc.)
- **Include explicit timeouts** if test involves background jobs or external APIs

## Common assertion patterns

```typescript
// URL assertions
expect(page.url()).toContain('/dashboard');
expect(page.url()).toMatch(/activity_report.*\\/review/);

// Text assertions
await expect(page.locator('h1')).toHaveText('Exact Title');
await expect(page.locator('h1')).toContainText('Partial');

// Visibility
await expect(page.locator('[data-testid="success"]')).toBeVisible();
await expect(page.locator('button')).toBeEnabled();

// Count elements
await expect(page.locator('li')).toHaveCount(3);

// State checking
await expect(page.locator('[data-testid="loading"]')).toBeHidden();
```

## Test structure guidelines

1. **Setup phase**: Initialize unique test data (emails, passwords, etc.)
2. **Preconditions phase**: Set up required state (accounts, certifications, etc.)
3. **Action phase**: Execute the user flow being tested
4. **Assertion phase**: Verify observable outcomes

## Timeout handling

```typescript
// For flows with known delays
test('user submits with document upload', async ({ page }) => {
  test.slow(); // 90-second timeout for external APIs
  // ... test code ...
});

// For very slow operations
test('user processes batch upload', async ({ page }) => {
  test.setTimeout(120000); // 2 minutes
  // ... test code ...
});

// Default timeout applies (30 seconds)
test('user fills simple form', async ({ page }) => {
  // No timeout needed
  // ... test code ...
});
```

## Test naming conventions

**Good examples:**
- `test('member can add multiple activities and submit report')`
- `test('exemption claim flow: user answers questions and uploads document')`
- `test('form shows validation error for empty email field')`
- `test('batch upload processes file and shows success message')`

**Bad examples:**
- `test('test1')` ← Unclear
- `test('flow')` ← Too vague
- `test('activity report form fill')` ← Incomplete (missing expected outcome)

**Pattern:** `<User role> can <action> and <expected outcome>`
