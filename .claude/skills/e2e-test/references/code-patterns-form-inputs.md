# Form Input Patterns

**For different form field types — use these patterns in page objects:**

| Input Type | Pattern | Notes |
|------------|---------|-------|
| Text field | `await field.fill('value')` | Clears existing text automatically |
| Number field | `await field.fill('123')` | Playwright handles as string; accepts numeric strings |
| Email field | `await field.fill('test@example.com')` | Use `@` to ensure email format |
| Textarea | `await field.fill('multiline\ntext')` | Use `\n` for line breaks |
| Select (dropdown) | `await page.selectOption('select#id', 'value')` | Or: `getByRole('combobox')` |
| Radio button (USWDS) | `await radio.dispatchEvent('click')` | Use `dispatchEvent`, not `.click()` |
| Checkbox (USWDS) | `await checkbox.check()` / `.uncheck()` | Playwright handles CSS-hidden elements |
| Date input | `await field.fill('12/25/2024')` | Match app's date format (MM/DD/YYYY) |
| File input | `await input.setInputFiles(['path/to/file.pdf'])` | Must be `input[type="file"]` |
| Auto-complete search | `await field.fill('search term')` → `await page.locator('option', { hasText: 'Match' }).click()` | Wait for dropdown options to appear |

## Example — Mixed form with various inputs

```typescript
async fillApplicationForm(firstName: string, email: string, stateCode: string) {
  // Text field
  await this.firstNameField.fill(firstName);

  // Email field
  await this.emailField.fill(email);

  // Select dropdown
  await this.page.selectOption('select[name="state"]', stateCode);

  // Radio button (USWDS hidden)
  await this.page.locator('input[value="yes"]').dispatchEvent('click');

  // Checkbox
  await this.agreeCheckbox.check();

  // Date input
  const today = new Date().toLocaleDateString('en-US');
  await this.dateField.fill(today);

  await this.submitButton.click();
  return new ConfirmationPage(this.page).waitForURLtoMatchPagePath();
}
```

## Page object with all input types

```typescript
import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';

export class ApplicationFormPage extends BasePage {
  get pagePath() {
    return '/application';
  }

  // Text fields
  readonly firstNameField: Locator;
  readonly lastNameField: Locator;

  // Email
  readonly emailField: Locator;

  // Textarea
  readonly commentsField: Locator;

  // Select dropdown
  readonly stateSelect: Locator;

  // Radio buttons (USWDS)
  readonly yesRadio: Locator;
  readonly noRadio: Locator;

  // Checkboxes
  readonly agreeCheckbox: Locator;
  readonly newsCheckbox: Locator;

  // Date input
  readonly dateOfBirthField: Locator;

  // File input
  readonly resumeInput: Locator;

  // Submit
  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);

    this.firstNameField = page.getByLabel(/first name/i);
    this.lastNameField = page.getByLabel(/last name/i);
    this.emailField = page.getByLabel(/email/i);
    this.commentsField = page.getByLabel(/comments/i);
    this.stateSelect = page.getByLabel(/state/i);
    this.yesRadio = page.locator('input[value="yes"]');
    this.noRadio = page.locator('input[value="no"]');
    this.agreeCheckbox = page.getByLabel(/agree to terms/i);
    this.newsCheckbox = page.getByLabel(/subscribe to newsletter/i);
    this.dateOfBirthField = page.getByLabel(/date of birth/i);
    this.resumeInput = page.locator('input[type="file"]');
    this.submitButton = page.getByRole('button', { name: /submit/i });
  }

  async fillAllFields(
    firstName: string,
    lastName: string,
    email: string,
    state: string,
    resume: string,
    comments?: string
  ) {
    // Text inputs
    await this.firstNameField.fill(firstName);
    await this.lastNameField.fill(lastName);
    await this.emailField.fill(email);

    // Comments textarea
    if (comments) {
      await this.commentsField.fill(comments);
    }

    // Select dropdown
    await this.page.selectOption('select[name="state"]', state);

    // Radio button (USWDS uses dispatchEvent)
    await this.yesRadio.dispatchEvent('click');

    // Checkboxes
    await this.agreeCheckbox.check();
    await this.newsCheckbox.check();

    // Date input
    const today = new Date().toLocaleDateString('en-US');
    await this.dateOfBirthField.fill(today);

    // File input
    await this.resumeInput.setInputFiles([resume]);

    // Submit
    await this.submitButton.click();
    await this.page.waitForLoadState('networkidle');

    return new ConfirmationPage(this.page).waitForURLtoMatchPagePath();
  }

  async fillPartialForm(firstName: string, email: string) {
    // Fill only required fields
    await this.firstNameField.fill(firstName);
    await this.emailField.fill(email);
    return this;
  }
}
```

## Common field scenarios

```typescript
// Text field with clear
await field.fill('');  // Clear the field
await field.fill('new value');

// Dropdown with option selection by text
const options = page.locator('select option');
const optionCount = await options.count();

// Radio button with attribute selector (not .click())
const radio = page.locator('input[type="radio"][value="male"]');
await radio.dispatchEvent('click');

// Checkbox state verification
const checkbox = page.getByLabel(/terms/i);
await checkbox.check();
await expect(checkbox).toBeChecked();
await checkbox.uncheck();
await expect(checkbox).not.toBeChecked();

// File input with wait
await input.setInputFiles(['file.pdf']);
await page.waitForLoadState('networkidle');  // Wait for upload

// Date field with parsed format
const date = new Date(2025, 2, 25);  // March 25, 2025
const formattedDate = date.toLocaleDateString('en-US');  // 3/25/2025
await dateField.fill(formattedDate);
```
