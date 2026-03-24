---
name: e2e-test
description: >
  Creates new Playwright end-to-end tests for the oscer reporting-app following the Page Object Model
  pattern. Use this skill whenever the user wants to write a new e2e test, add test coverage for a UI
  flow, or says things like "write an e2e test for...", "add a playwright test for...", "test the
  [flow name] flow", or "create a spec for...". Also trigger when the user describes a UI flow and
  asks for test coverage without explicitly mentioning Playwright. Always invoke this skill before
  writing any test code — it handles server availability checking, live app exploration via Playwright
  MCP, and generates idiomatic test files that match the project's existing conventions.
---

# e2e-test skill

You help write new Playwright end-to-end tests for the **oscer reporting-app** — a Rails 7.2
government-benefits app. Tests live in `e2e/reporting-app/` and follow a Page Object Model (POM)
pattern with flow orchestrators for multi-step scenarios.

The argument passed to this skill is a **description of the UI flow to test**.

---

## Step 1 — Check if localhost:3000 is running

Use the Playwright MCP tool (`mcp__playwright__browser_navigate`) to navigate to
`http://localhost:3000`. A redirect to the login page or a dashboard page means the server is up.
A connection error or timeout means it is not.

**If not running:**
1. Tell the user: "The local server isn't running. Let me build it first."
2. Run in the terminal:
   ```bash
   cd /Users/baonguyen/Documents/NavaGithub/oscer/reporting-app && make build
   ```
3. Ask: "Would you like to start with `make start-container` (Docker) or `make start-native` (native Ruby)?"
4. Instruct them to run the chosen command in a separate terminal, then confirm when it's up.
5. Once confirmed, navigate to `http://localhost:3000` again to verify.

---

## Step 2 — Ask clarifying questions if needed

If the flow description is ambiguous, ask before exploring. Common questions:
- Member-facing or staff-facing flow?
- Does this flow require an existing certification/account, or start from scratch?
- What is the observable success state? (URL change, text on page, redirect, etc.)
- Are there any fixture files (PDFs, images) needed?
- Is this a happy path only, or should edge cases be covered?

Don't ask questions that you can answer by looking at the live app.

---

## Step 3 — Explore the live app with Playwright MCP

Navigate to each page involved in the described flow using the Playwright MCP tools. For each page:
- Use `mcp__playwright__browser_snapshot` to capture the accessibility tree
- Note the actual URL, locators, button labels, form field names, and any dynamic URL segments
- Click through the flow to understand the sequence and redirects
- Identify which **existing** page objects and flows cover these pages (see reference below)

This live exploration is the most important step — it gives you accurate locators and real URL
patterns rather than assumptions.

---

## Step 4 — Plan the test structure

Before writing code, outline:
1. Which existing page objects (`BasePage` subclasses) can be reused as-is
2. Which page objects need a new method added
3. Which pages need a brand new `Page` class
4. Whether a new `Flow` class is warranted (use flows for 5+ sequential steps)
5. The test file name and the assertion(s) at the end

Share this plan briefly with the user before writing — "I'll reuse X and Y, create a new Z page
object, and write the test to assert [outcome]. Does that sound right?"

---

## Step 5 — Write the code

Generate all files needed:

### Test file — `e2e/reporting-app/tests/<name>.spec.ts`

```typescript
import path from 'path'; // only if file fixtures needed
import { expect } from '@playwright/test';
import { test } from '../../fixtures'; // ALWAYS use custom fixture, not base test
import { SomePageOrFlow } from '../pages'; // or flows
import { AccountCreationFlow } from '../flows';

test('descriptive test name: what happens', async ({ page, emailService }) => {
  // Set explicit timeout for flows that hit background jobs or external APIs
  // test.setTimeout(120000);
  // Or use test.slow() to triple the default timeout for moderately slow tests

  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';

  // Standard setup (if certification + sign-in needed):
  const certPage = await new CertificationRequestPage(page).go();
  await certPage.fillAndSubmit(email);
  const accountCreationFlow = new AccountCreationFlow(page, emailService);
  const signInPage = await accountCreationFlow.run(email, password);
  const mfaPage = await signInPage.signIn(email, password);
  await mfaPage.skipMFA();

  // Flow-specific steps...

  // Assertion — always assert something observable:
  expect(page.url()).toContain('/expected-path');
  // or: await expect(page.locator('h1')).toHaveText('Expected Heading');
});
```

### Page object — `e2e/reporting-app/pages/<dir>/<Name>Page.ts`

```typescript
import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage'; // adjust relative path

export class ExamplePage extends BasePage {
  get pagePath() {
    return '/example/path'; // use * for dynamic segments: '/forms/*/edit'
  }

  readonly submitButton: Locator;
  readonly someField: Locator;

  constructor(page: Page) {
    super(page);
    this.submitButton = page.getByRole('button', { name: /submit/i });
    this.someField = page.getByLabel('Field label');
  }

  async fillAndSubmit(value: string) {
    await this.someField.fill(value);
    await this.submitButton.click();
    return new NextPage(this.page).waitForURLtoMatchPagePath();
  }
}
```

**USWDS quirks:**
- Radio buttons and checkboxes are often CSS-hidden by USWDS styling — use
  `await element.dispatchEvent('click')` instead of `.click()` when `.click()` fails
- File inputs: use `page.locator('input[type="file"]').setInputFiles([...])`
- Wait after background job triggers: `await page.waitForLoadState('networkidle')`

### Flow class (if 5+ steps) — `e2e/reporting-app/flows/<Name>Flow.ts`

```typescript
import { Page } from '@playwright/test';
import { PageOne } from '../pages/...';
import { PageTwo } from '../pages/...';

export class ExampleFlow {
  page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async run(/* relevant args */) {
    const page1 = await new PageOne(this.page).go();
    const page2 = await page1.someAction();
    // ...
    return new FinalPage(this.page);
  }
}
```

### Update barrel exports

After creating new files, add them to the appropriate `index.ts`:
- New member page → `e2e/reporting-app/pages/members/index.ts`
- New activity-report page → `e2e/reporting-app/pages/members/activity-reports/index.ts`
- New staff page → `e2e/reporting-app/pages/staff/index.ts`
- New flow → `e2e/reporting-app/flows/index.ts`

---

## Reference — existing building blocks

See `references/existing-pages-and-flows.md` for the full catalog of existing page objects and
flow classes to reuse before creating new ones.

---

## Step 6 — Show the user

Present every file you wrote — test spec, any new page objects, any new flows — with their full
paths. Remind the user how to run just this test:

```bash
cd /Users/baonguyen/Documents/NavaGithub/oscer/e2e
APP_NAME=reporting-app npx playwright test reporting-app/tests/<filename>.spec.ts
```

If the test involves background jobs or DocAI, remind them that the test may take several minutes
and to check the timeout setting.
