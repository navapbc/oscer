# Error Message Assertions

**For tests that verify error handling:**

## Basic error assertion patterns

```typescript
// Missing required field
await form.submit();
await expect(page.locator('[role="alert"]')).toContainText('Email is required');

// Invalid input
await emailField.fill('not-an-email');
await submitButton.click();
await expect(page.locator('.field-error')).toContainText('Enter a valid email');

// Server error message
await expect(page.locator('[role="alert"]')).toContainText('An error occurred. Please try again.');

// Inline validation error
const errorMsg = page.locator('text=Field is required');
await expect(errorMsg).toBeVisible();
```

## Page object with error handling

```typescript
import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';

export class FormPage extends BasePage {
  get pagePath() {
    return '/form';
  }

  readonly emailField: Locator;
  readonly submitButton: Locator;
  readonly errorAlert: Locator;
  readonly fieldErrorMessages: Locator;

  constructor(page: Page) {
    super(page);
    this.emailField = page.getByLabel(/email/i);
    this.submitButton = page.getByRole('button', { name: /submit/i });
    this.errorAlert = page.locator('[role="alert"]');
    this.fieldErrorMessages = page.locator('[role="alert"]');
  }

  async submitWithEmptyEmail() {
    // Leave email empty and submit
    await this.submitButton.click();

    // Verify validation error appears
    await expect(this.errorAlert).toContainText('Email is required');
    return this;
  }

  async submitWithInvalidEmail() {
    await this.emailField.fill('not-an-email');
    await this.submitButton.click();

    await expect(this.errorAlert).toContainText('Enter a valid email');
    return this;
  }

  async verifyErrorMessage(message: string) {
    await expect(this.errorAlert).toContainText(message);
    return this;
  }

  async clearAndRetry(validEmail: string) {
    await this.emailField.fill(validEmail);
    await this.submitButton.click();
    // Should succeed now
    return new SuccessPage(this.page).waitForURLtoMatchPagePath();
  }
}
```

## Test cases for error scenarios

```typescript
import { expect } from '@playwright/test';
import { test } from '../../fixtures';
import { FormPage } from '../pages';

test('form shows validation error for empty email', async ({ page }) => {
  const form = new FormPage(page).waitForURLtoMatchPagePath();

  await form.submitWithEmptyEmail();

  expect(page.url()).toContain('/form');
});

test('form shows validation error for invalid email', async ({ page }) => {
  const form = await new FormPage(page).waitForURLtoMatchPagePath();

  await form.submitWithInvalidEmail();

  expect(page.url()).toContain('/form');
});

test('user can recover from validation error', async ({ page }) => {
  const form = await new FormPage(page).waitForURLtoMatchPagePath();

  // First submission fails
  await form.submitWithInvalidEmail();

  // User corrects and retries
  const success = await form.clearAndRetry('valid@example.com');

  expect(page.url()).toContain('/success');
});
```

## Multiple field errors

```typescript
export class MultiFieldFormPage extends BasePage {
  get pagePath() {
    return '/registration';
  }

  readonly firstNameField: Locator;
  readonly emailField: Locator;
  readonly passwordField: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.firstNameField = page.getByLabel(/first name/i);
    this.emailField = page.getByLabel(/email/i);
    this.passwordField = page.getByLabel(/password/i);
    this.submitButton = page.getByRole('button', { name: /register/i });
  }

  async submitWithoutFillingFields() {
    await this.submitButton.click();

    // Verify all errors appear
    const errors = this.page.locator('[role="alert"]');
    const errorCount = await errors.count();

    expect(errorCount).toBeGreaterThanOrEqual(3);
    await expect(errors.first()).toContainText(/required|must fill|cannot be blank/i);

    return this;
  }

  async submitAndExpectSpecificErrors(expectedErrors: string[]) {
    await this.submitButton.click();

    for (const error of expectedErrors) {
      await expect(this.page.locator('[role="alert"]')).toContainText(error);
    }

    return this;
  }
}
```

## Network/server error handling

```typescript
// Server returns 500 error
test('shows error message on server error', async ({ page }) => {
  const form = await new FormPage(page).waitForURLtoMatchPagePath();

  // Simulate server error by using a test-specific endpoint
  await form.emailField.fill('error@example.com');
  await form.submitButton.click();

  // Server error message displayed
  await expect(page.locator('[role="alert"]')).toContainText(
    'An error occurred. Please try again later.'
  );

  // Still on same form page
  expect(page.url()).toContain('/form');
});
```
