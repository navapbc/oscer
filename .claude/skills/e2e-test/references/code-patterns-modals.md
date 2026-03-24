# Modals & Dialogs Patterns

**For pages with modal dialogs, confirmation popups, or overlay messages:**

| Scenario | Pattern | Notes |
|----------|---------|-------|
| Wait for modal to open | `await page.locator('[role="dialog"]').waitFor()` | USWDS modals use `role="dialog"` |
| Verify modal text | `await expect(page.locator('[role="dialog"]')).toContainText('Message')` | Check modal shows expected content |
| Click modal button | `page.locator('[role="dialog"]').getByRole('button', { name: /confirm/i }).click()` | Click button inside modal |
| Close modal (ESC key) | `await page.keyboard.press('Escape')` | Some modals close on ESC |
| Modal dismissal waits | After modal action: `await page.locator('[role="dialog"]').waitFor({ state: 'hidden' })` | Wait for modal to close |
| Toast/alert messages | `await expect(page.locator('[role="alert"]')).toContainText('Success')` | USWDS alerts use `role="alert"` |

## Example — Confirmation modal

```typescript
// Page object method
async submitWithConfirmation() {
  await this.submitButton.click();

  // Wait for confirmation modal
  const modal = page.locator('[role="dialog"]');
  await modal.waitFor();

  // Verify content and click confirm
  await expect(modal).toContainText('Are you sure?');
  await modal.getByRole('button', { name: /confirm/i }).click();

  // Wait for modal to close and navigation
  await modal.waitFor({ state: 'hidden' });
  return new SuccessPage(this.page).waitForURLtoMatchPagePath();
}
```

## Page object with modal handling

```typescript
export class ReviewPage extends BasePage {
  get pagePath() {
    return '/review';
  }

  readonly submitButton = this.page.getByRole('button', { name: /submit/i });
  readonly confirmModal = this.page.locator('[role="dialog"]');

  async submitWithConfirmation() {
    await this.submitButton.click();
    await this.confirmModal.waitFor();

    // Verify confirmation message
    await expect(this.confirmModal).toContainText('Submit this application?');

    // Click confirm button inside modal
    await this.confirmModal.getByRole('button', { name: /confirm/i }).click();

    // Wait for modal to close
    await this.confirmModal.waitFor({ state: 'hidden' });
    return new SuccessPage(this.page).waitForURLtoMatchPagePath();
  }

  async cancelModal() {
    // Can cancel via button or ESC key
    await this.page.keyboard.press('Escape');
    await this.confirmModal.waitFor({ state: 'hidden' });
    return this;
  }
}
```

## Toast/alert notification handling

```typescript
export class FormPage extends BasePage {
  readonly successAlert = this.page.locator('[role="alert"]');

  async submitAndExpectSuccess() {
    await this.submitButton.click();

    // Wait for success alert
    await this.successAlert.waitFor();
    await expect(this.successAlert).toContainText('Successfully submitted');

    return new NextPage(this.page).waitForURLtoMatchPagePath();
  }

  async submitAndExpectError(errorMessage: string) {
    await this.submitButton.click();

    // Alert stays on same page for validation errors
    await this.successAlert.waitFor();
    await expect(this.successAlert).toContainText(errorMessage);

    return this;
  }
}
```
