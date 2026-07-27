import { expect, Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ChooseMonthsPage } from './ChooseMonthsPage';

export class BeforeYouStartPage extends BasePage {
  get pagePath() {
    return '/activity_report_application_forms/new?*';
  }

  readonly startButton: Locator;
  readonly skipAiCheckbox: Locator;

  constructor(page: Page) {
    super(page);
    this.startButton = page.getByRole('button', { name: /start/i });
    this.skipAiCheckbox = page.locator('.usa-checkbox__label') || page.getByLabel(/skip ai/i);
  }

  async clickStart() {
    // Skip DocAI when the checkbox is present (FEATURE_DOC_AI); otherwise Start goes
    // straight to the classic months / supporting-documents path.
    // Click the visible label — the USWDS tile input is off-viewport and
    // `.check()` on `.usa-checkbox__input` times out in CI.
    if ((await this.skipAiCheckbox.count()) > 0) {
      await this.skipAiCheckbox.check();
    }
    await this.startButton.click();

    return new ChooseMonthsPage(this.page).waitForURLtoMatchPagePath();
  }

  async clickStartWithDocAi() {
    // Verify DocAI is not being skipped (checkbox must be unchecked by default)
    await expect(this.page.locator('.usa-checkbox__input')).not.toBeChecked();
    await this.startButton.click();
    return new ChooseMonthsPage(this.page).waitForURLtoMatchPagePath();
  }
}
