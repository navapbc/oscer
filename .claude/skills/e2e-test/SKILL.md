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

## ⚠️ Plan Mode Required

**ALWAYS enter plan mode first.** Do not write any code until the user approves the plan.

1. **Gather information**: Steps 1–4 (check localhost:3000, ask questions, explore live app, plan structure)
2. **Create a plan file** using your plan tool with:
   - Which existing page objects can be reused as-is
   - Which pages need new methods or brand new `Page` classes
   - Whether a new `Flow` class is warranted
   - Test file name and final assertions
   - Example: "Reuse `LoginPage` and `DashboardPage`, create new `ExemptionDetailsPage` with `fillClaim()` method, test file: `exemption-claim.spec.ts`, assertion: 'expect URL to match /exemptions/*/submitted'"
3. **Exit plan mode** only after the user explicitly approves
4. **Write code** (Steps 5–6) only after approval
5. **Validate** in two phases: CLI test first, then Playwright MCP live walkthrough

This ensures the plan is correct before generating any files.

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
   cd /oscer/reporting-app && make build
   ```
3. Ask: "Would you like to start with `make start-container` (Docker) or `make start-native` (native Ruby)?"
4. Instruct them to run the chosen command in a separate terminal, then confirm when it's up.
5. Once confirmed, navigate to `http://localhost:3000` again to verify.

---

## Step 2 — Ask clarifying questions if needed

If the flow description is ambiguous, ask before exploring. Common questions:
- Member-facing or staff-facing flow?
- Does this flow require an existing certification/account, or start from scratch?
- **Skip account creation?** While using the Playwright MCP to verify the testing flow, would you like to skip account creation and use existing credentials?
- **Login credentials:** If skipping account creation, what login credentials (email/password) would you like to use? (These are specific to your local environment).
- What is the observable success state? (URL change, text on page, redirect, etc.)
- Are there any fixture files (PDFs, images) needed?
- Is this a happy path only, or should edge cases be covered?

Don't ask questions that you can answer by looking at the live app.

---

## Step 3 — Explore the live app with Playwright MCP

Navigate to each page involved in the described flow using the Playwright MCP tools. For each page:

**Capture the page state:**
- Use `mcp__playwright__browser_snapshot` to capture the accessibility tree
- Note the actual URL, page title, and any dynamic URL segments

**Document form fields & buttons EXACTLY as they appear:**
- For buttons: `getByRole('button', { name: /exact label/i })`
- For text fields: `getByLabel('Field Label')` OR `getByPlaceholder('Hint text')`
- For selects/dropdowns: `getByLabel('Select label')` and available options
- For USWDS radio/checkbox groups: note that elements are CSS-hidden (will use `dispatchEvent`)
- For links: `getByRole('link', { name: /link text/i })`

**Test the locators live in the browser console:**
- Before writing code, verify at least 1-2 critical locators work
- Use Playwright DevTools in the browser to confirm selectors actually match

**Click through the flow:**
- Understand the exact sequence: which button goes where, what page comes next
- Note any async delays or page redirects
- Check if any background jobs run (look for loading spinners, network activity)

**Check the reference file:**
- See `references/existing-pages-and-flows.md` for all existing page objects
- Identify which pages you can **reuse exactly** vs. which need new methods added

**This step is critical:** Inaccurate locators cause test failures. Spend time here to get URLs, field labels, and button text exactly right.

---

## Step 4 — Plan the test structure

Before writing code, outline:
1. Which existing page objects (`BasePage` subclasses) can be reused as-is
2. Which page objects need a new method added
3. Which pages need a brand new `Page` class
4. Whether a new `Flow` class is warranted (use flows for 5+ sequential steps)
5. The test file name and the assertion(s) at the end

**Page Object Completeness Checklist:**
For EACH page object you plan to create or modify, document:
- ✓ **pagePath:** Exact URL pattern (with `*` for dynamic segments)
- ✓ **All locators needed:** Button, form fields, links, etc. (with exact labels from Step 3)
- ✓ **All methods needed:** Each method name, parameters, and return type
- ✓ **USWDS quirks:** Which fields need `dispatchEvent('click')` vs. `.click()`
- ✓ **Async handling:** Does this page need `.waitForLoadState('networkidle')` after form submit?
- ✓ **Return types:** What page object does each method return (for chaining)?

**Example checklist entry:**
```
ActivityDetailsPage
- pagePath: /activity_report_application_forms/*/activity_detail
- Locators: employerNameField (text), hoursField (number), continueButton
- Methods:
  - async fillActivityDetails(name: string, hours: string) → SupportingDocumentsPage
- USWDS: Hours field may need dispatchEvent
- Async: No special wait needed
```

Share this plan with the user: "I'll reuse X and Y, create a new Z page object with these methods [list], and write the test to assert [outcome]. Does that sound right?"

**⏸️ STOP — Plan Approval Required**

Use the plan tool (`ExitPlanMode`) to present the plan and pause. **Do not proceed to Step 5 until the user explicitly approves.** Only after the user says "approved" or "looks good" should you continue.

---

## Step 5 — Write the code

Generate all files needed:

### Test file — `e2e/reporting-app/tests/<name>.spec.ts`

### Page object — `e2e/reporting-app/pages/<dir>/<Name>Page.ts`

### Flow class (if 5+ steps) — `e2e/reporting-app/flows/<Name>Flow.ts`

### Step 5c — Update barrel exports (REQUIRED)

**CRITICAL:** Every new file MUST be exported from its barrel `index.ts`, or the test will fail at import.

**Barrel Export Checklist:**

For each new file created, add to the appropriate `index.ts`:

```typescript
// pages/members/index.ts (example)
export { DashboardPage } from './DashboardPage';
export { NewPageName } from './NewPageName'; // ← ADD THIS

// pages/members/activity-reports/index.ts
export { ActivityReportPage } from './ActivityReportPage';
export { NewActivityReportPage } from './NewActivityReportPage'; // ← ADD THIS

// flows/index.ts
export { AccountCreationFlow } from './AccountCreationFlow';
export { NewFlowName } from './NewFlowName'; // ← ADD THIS
```

**Before validation (Step 6), verify:**
- ✓ Every new `.ts` file has a corresponding export in its barrel `index.ts`
- ✓ Test imports match the barrel exports: `import { NewPage } from '../pages'` works
- ✓ No circular dependencies (page A imports page B, page B imports page A)

**If test fails with `Cannot find module` error:**
- Check if the file was exported from `index.ts`
- Check import path is relative (e.g., `import { DashboardPage } from '../pages'`)
- Re-run test after adding export

---

## Step 6 — Validate generated code (Two-Phase Validation)

**CRITICAL:** Before presenting tests to the user, validate them in two phases:

### Phase A — CLI test dry-run (validate the code compiles and runs)

1. **Navigate to the e2e directory:**
   ```bash
   cd oscer/e2e
   ```

2. **Run the generated test file against the live app:**
   ```bash
   APP_NAME=reporting-app npx playwright test reporting-app/tests/<filename>.spec.ts
   ```

3. **If the test passes:**
   - ✅ Code is syntactically correct and executes. Proceed to Phase B.

4. **If the test fails:**
   - ❌ Read the Playwright error message carefully
   - Identify the failure type (see Common Failure Patterns below)
   - Fix the generated code
   - Re-run the test (single file only)
   - Repeat until passing, then proceed to Phase B

**Common Failure Patterns & Fixes:**

| Error | Cause | Fix |
|-------|-------|-----|
| `Locator not found: getByLabel('...')` | Form field label doesn't match | Re-run Step 3 live exploration; check exact label text on page |
| `Locator not found: getByRole('button', ...)` | Button label doesn't match | Check button text; may need `getByText()` or `page.locator()` |
| `Timeout waiting for navigation` | Page didn't navigate to expected URL | Check `pagePath` — may be wrong or dynamic segments missing |
| `Element not visible / not actionable` | USWDS CSS-hidden element | Replace `.click()` with `dispatchEvent('click')` |
| `Timeout waiting for... networkidle` | Page load took too long | Increase timeout: `test.setTimeout(30000)` or `test.slow()` |
| `Cannot read property 'signIn'` | Return type wrong (method doesn't exist) | Verify method exists on returned page object; check import |

---

### Phase B — Playwright MCP live walkthrough (catch hidden plan mismatches)

**Why both phases?**
- **Phase A** validates that code *compiles and runs* against the test data
- **Phase B** validates that the plan *matches the actual app* — URLs, labels, button text, navigation flow

A test can pass Phase A but still fail in production if the plan contained errors (e.g., button label typo, URL path mismatch, page doesn't redirect as expected).

After the CLI test passes, manually walk through the flow on `localhost:3000` to verify:

1. **Use Playwright MCP** to navigate through each page in the flow:
   - `mcp__playwright__browser_navigate('http://localhost:3000/<path>')` to go to each page
   - `mcp__playwright__browser_snapshot` to capture the page structure
   - Verify that all planned locators (`getByLabel`, `getByRole`, etc.) actually exist on the page
   - Check button labels, form field names, and page URLs match what was planned

2. **Click through the entire user flow** using Playwright MCP:
   - Fill each form field with test data
   - Click each button
   - Verify page transitions happen as expected
   - Confirm final URL matches the expected destination

3. **If the live walkthrough passes:**
   - ✅ Plan is accurate and code works. Proceed to Step 7.

4. **If the live walkthrough fails:**
   - ❌ A locator doesn't exist or page structure differs from plan
   - Go back to Step 3 (live exploration) and re-document the actual page structure
   - Update the plan with the correct information
   - Regenerate the page object / test code
   - Re-run Phase A, then Phase B again

**Why Phase B matters:** A test that passes the CLI but doesn't match the actual app indicates a bad plan. Phase B catches these mismatches before handing the test off to the user.

---

## Step 7 — Show the user

Present every file you wrote — test spec, any new page objects, any new flows — with their full
paths. Include a note that the test was **validated and passes on localhost**.

Remind the user how to run the test:

```bash
cd oscer/e2e
APP_NAME=reporting-app npx playwright test reporting-app/tests/<filename>.spec.ts
```

If the test involves background jobs or DocAI, remind them that the test may take several minutes
and to check the timeout setting.

---

## Test Anti-Patterns to Avoid (Reference)

**DON'T do these — they cause flaky or fragile tests:**

| Anti-Pattern | Why It's Bad | Fix |
|--------------|-------------|-----|
| `await page.waitForTimeout(1000)` | Arbitrary waits are flaky and slow | Use `waitForLoadState()`, `waitForSelector()`, `waitFor()` |
| `page.locator('div').first()` | Too vague; brittle to DOM changes | Use accessible selectors: `getByRole()`, `getByLabel()`, `getByText()` |
| `expect(page).toHaveTitle('Exact Title')` | Page title might vary slightly | Use URL or heading assertions instead |
| `test('test name')` with no description | Unclear what's being tested | Use descriptive: `test('user can add activity and submit')` |
| Assertions after navigation without wait | Races against page load | Always use `.waitForURLtoMatchPagePath()` or `.waitForLoadState()` |
| Multiple assertions without grouping | Hard to debug which one fails | Group related assertions together |
| No timeout for slow flows | Tests time out randomly | Use `test.slow()` or `test.setTimeout()` |
| Using hardcoded IDs in selectors | IDs change; test breaks | Use labels, roles, text content (semantic) |

---

## Test Naming Conventions (Reference)

**Use clear, descriptive test names that explain the user action and expected outcome:**

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

## Final Validation Checklist — Before Handing Off to User

Use this checklist **AFTER Step 6 validation passes** and **BEFORE Step 7 handoff**:

### Test File
- ✓ Imports custom `test` from `../../fixtures` (NOT `@playwright/test`)
- ✓ Imports all page objects from barrel exports (`../pages`, `../flows`)
- ✓ Has at least one observable assertion (URL, text, visibility, etc.)
- ✓ Unique test data generated (email address, etc.)
- ✓ Test passes on first run (no flakes after 1 attempt)

### Page Objects
- ✓ All form fields defined as `readonly Locator` properties
- ✓ All user-facing methods implemented and return next page type
- ✓ `pagePath` includes `*` for dynamic URL segments
- ✓ Methods use `getByLabel`/`getByRole`/`getByPlaceholder` (accessibility-first)
- ✓ USWDS quirks handled (hidden elements use `dispatchEvent`, etc.)
- ✓ Proper async waits after forms (`.waitForURLtoMatchPagePath()` or `.waitForLoadState()`)

### Flows (if created)
- ✓ 5+ steps in the workflow
- ✓ Methods chain page objects with proper navigation
- ✓ Returns final page type for test assertions
- ✓ Comments explain each step

### Exports
- ✓ All new `.ts` files exported from barrel `index.ts`
- ✓ No import/module errors
- ✓ No circular dependencies

### Timeout & Async
- ✓ `test.slow()` or `test.setTimeout()` added if flow involves external APIs, email, etc.
- ✓ `waitForLoadState('networkidle')` after forms/uploads that trigger background jobs
- ✓ No arbitrary `await page.waitForTimeout(X)` (use meaningful waits instead)

### Test Quality & Anti-Patterns
- ✓ Test name is descriptive: `<user role> can <action> and <outcome>`
- ✓ No arbitrary `waitForTimeout()` — uses semantic waits instead
- ✓ No vague selectors like `locator('div')` — uses `getByRole()`, `getByLabel()`, etc.
- ✓ No assertions after navigation without `waitForURL` or `waitForLoadState`
- ✓ Error messages tested with `toContainText()` (not exact match)
- ✓ All form inputs tested with correct patterns (not mixing `.fill()` and `.click()`)

### Test Execution
- ✓ Test runs with: `APP_NAME=reporting-app npx playwright test reporting-app/tests/<filename>.spec.ts`

---
