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
    const skipInput = this.page.locator('.usa-checkbox__input');
    if ((await skipInput.count()) > 0) {
      await skipInput.check();
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
