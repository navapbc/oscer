# Page Object Template

**Location:** `e2e/reporting-app/pages/<dir>/<Name>Page.ts`

## Full page object example

```typescript
import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage'; // adjust relative path (use correct depth)

export class ActivityDetailsPage extends BasePage {
  get pagePath() {
    return '/activity_report_application_forms/*/activity_detail';
  }

  // Define ALL form fields as properties (in order they appear on page)
  readonly employerNameField: Locator;
  readonly hoursField: Locator;
  readonly continueButton: Locator;

  constructor(page: Page) {
    super(page);
    // Use accessibility-first selectors: getByLabel, getByRole, getByPlaceholder
    this.employerNameField = page.getByLabel(/employer name/i);
    this.hoursField = page.getByLabel(/hours worked/i);
    this.continueButton = page.getByRole('button', { name: /continue/i });
  }

  // Implement all methods from Step 4 checklist
  async fillActivityDetails(employerName: string, hours: string) {
    await this.employerNameField.fill(employerName);
    // If field is USWDS hidden, use dispatchEvent instead of fill
    await this.hoursField.fill(hours);
    await this.continueButton.click();
    // Always wait for navigation after form submission
    return new SupportingDocumentsPage(this.page).waitForURLtoMatchPagePath();
  }

  // If page has other actions, add them as separate methods
  async fillEmployerOnly(name: string) {
    await this.employerNameField.fill(name);
    // Don't click submit—return this for further chaining
    return this;
  }
}
```

## Requirements

- **Define ALL form fields** as `readonly Locator` properties
- **Implement ALL user-facing methods** from Step 4 checklist
- **Return the next page type** from each method (for chaining)
- **Include proper async/await** for navigation waits
- **Use accessibility-first selectors:** `getByLabel`, `getByRole`, `getByPlaceholder` (not brittle CSS selectors)

## USWDS quirks

### Radio buttons & checkboxes: Often CSS-hidden

If `.click()` fails: use `await element.dispatchEvent('click')`

```typescript
readonly agreeCheckbox = this.page.getByLabel(/agree/i);

async acceptTerms() {
  // USWDS checkboxes handle click properly
  await this.agreeCheckbox.check();
  return this;
}
```

Or for radio buttons:

```typescript
readonly yesRadio = this.page.locator('input[value="yes"]');

async selectYes() {
  // Use dispatchEvent for USWDS hidden radios
  await this.yesRadio.dispatchEvent('click');
  return this;
}
```

### File inputs

```typescript
readonly resumeInput = this.page.locator('input[type="file"]');

async uploadFile(filePath: string) {
  await this.resumeInput.setInputFiles([filePath]);
  // Wait for upload to complete
  await this.page.waitForLoadState('networkidle');
  return new NextPage(this.page).waitForURLtoMatchPagePath();
}
```

### Form submission with async load

```typescript
async submitForm() {
  await this.submitButton.click();

  // If next page has delayed load (API call, background job):
  await this.page.waitForLoadState('networkidle');
  return new NextPage(this.page).waitForURLtoMatchPagePath();
}
```

## Complete page object with all scenarios

```typescript
import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';

export class ApplicationFormPage extends BasePage {
  get pagePath() {
    return '/applications/*/form';
  }

  // Text fields
  readonly firstNameField: Locator;
  readonly lastNameField: Locator;
  readonly emailField: Locator;

  // Select dropdown
  readonly stateSelect: Locator;

  // USWDS hidden elements
  readonly agreeCheckbox: Locator;
  readonly yesRadio: Locator;

  // File input
  readonly documentInput: Locator;

  // Buttons
  readonly continueButton: Locator;
  readonly cancelButton: Locator;

  constructor(page: Page) {
    super(page);

    this.firstNameField = page.getByLabel(/first name/i);
    this.lastNameField = page.getByLabel(/last name/i);
    this.emailField = page.getByLabel(/email/i);
    this.stateSelect = page.getByLabel(/state/i);
    this.agreeCheckbox = page.getByLabel(/agree to terms/i);
    this.yesRadio = page.locator('input[value="yes"]');
    this.documentInput = page.locator('input[type="file"]');
    this.continueButton = page.getByRole('button', { name: /continue/i });
    this.cancelButton = page.getByRole('button', { name: /cancel/i });
  }

  async fillBasicInfo(firstName: string, lastName: string, email: string) {
    await this.firstNameField.fill(firstName);
    await this.lastNameField.fill(lastName);
    await this.emailField.fill(email);
    return this;
  }

  async selectState(stateCode: string) {
    await this.page.selectOption('select[name="state"]', stateCode);
    return this;
  }

  async agreeToTerms() {
    // USWDS checkbox—check() handles hidden elements
    await this.agreeCheckbox.check();
    return this;
  }

  async selectYesOption() {
    // USWDS radio—use dispatchEvent
    await this.yesRadio.dispatchEvent('click');
    return this;
  }

  async uploadDocument(filePath: string) {
    await this.documentInput.setInputFiles([filePath]);
    await this.page.waitForLoadState('networkidle');
    return this;
  }

  async submitForm() {
    await this.continueButton.click();
    await this.page.waitForLoadState('networkidle');
    return new ConfirmationPage(this.page).waitForURLtoMatchPagePath();
  }

  async cancel() {
    await this.cancelButton.click();
    return new DashboardPage(this.page).waitForURLtoMatchPagePath();
  }
}
```

## Locator selector priority

1. **`getByLabel()`** – Most reliable for form fields with labels
2. **`getByRole()`** – Semantic: buttons, links, headings with role
3. **`getByPlaceholder()`** – For inputs without labels
4. **`getByText()`** – For text content (links, buttons)
5. **`locator('[data-testid]')`** – Test IDs if data-testid present
6. **Avoid:** Generic selectors like `locator('div')`, CSS IDs that change

## Method return types

- Methods that submit/navigate should return the next `Page` object
- Methods that fill fields should return `this` for chaining
- Methods that verify state can return `this` or nothing

```typescript
async fillAndSubmit(name: string) {
  await this.nameField.fill(name);
  await this.submitButton.click();
  return new NextPage(this.page).waitForURLtoMatchPagePath(); // Return next page
}

async fillNameOnly(name: string) {
  await this.nameField.fill(name);
  return this; // Return same page for further chaining
}
```
