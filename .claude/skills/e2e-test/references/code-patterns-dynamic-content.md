# Dynamic Content & Lists Patterns

**For pages with dynamically rendered lists, tables, or conditionally visible elements:**

| Scenario | Pattern | Example |
|----------|---------|---------|
| Click nth item in list | `page.locator('li').nth(N).click()` | Click 3rd activity: `page.locator('[data-testid="activity"]').nth(2).click()` |
| Verify list has N items | `await expect(page.locator('li')).toHaveCount(N)` | Check 3 activities added |
| Find & click by text | `page.getByText(/exact text/).click()` | Click button with dynamic text |
| Wait for element to appear | `await page.locator('.dynamic-element').waitFor()` | Wait for spinner to disappear |
| Get text from element | `const text = await page.locator('h1').textContent()` | Extract heading for assertion |
| Conditional visibility | `await expect(page.locator('.success')).toBeVisible()` / `toBeHidden()` | Check success message appears |

## Common patterns

```typescript
// List with dynamic count
const activityCount = await page.locator('[data-testid="activity"]').count();
expect(activityCount).toBe(3);

// Wait then interact
await page.locator('[role="dialog"]').waitFor();
await page.locator('button', { hasText: 'Confirm' }).click();

// Assertion on dynamic content
const status = await page.locator('[data-testid="status"]').textContent();
expect(status?.trim()).toBe('Submitted');
```

## Page object example with dynamic lists

```typescript
export class ActivitiesListPage extends BasePage {
  get pagePath() {
    return '/activities';
  }

  readonly addActivityButton = this.page.getByRole('button', { name: /add activity/i });

  async getActivityCount(): Promise<number> {
    return this.page.locator('[data-testid="activity-item"]').count();
  }

  async clickActivityByIndex(index: number) {
    await this.page.locator('[data-testid="activity-item"]').nth(index).click();
    return new ActivityDetailPage(this.page).waitForURLtoMatchPagePath();
  }

  async waitForActivitiesToLoad() {
    await this.page.locator('[data-testid="activity-item"]').first().waitFor();
    return this;
  }

  async verifyActivityCount(expectedCount: number) {
    await expect(this.page.locator('[data-testid="activity-item"]')).toHaveCount(expectedCount);
    return this;
  }
}
```
