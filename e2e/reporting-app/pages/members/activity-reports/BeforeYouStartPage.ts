import { Locator, Page } from '@playwright/test';
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
    this.skipAiCheckbox = page.getByLabel(/skip ai/i);
  }

  // Skip DocAI for original document upload flow
  async clickStart(skipDocAi: boolean = true) {
    // Check "Skip AI" checkbox if DocAI is enabled and we want to skip it
    try {
      const isCheckboxVisible = await this.skipAiCheckbox.isVisible().catch(() => false);
      if (isCheckboxVisible && skipDocAi) {
        await this.skipAiCheckbox.check();
      }
    } catch {
      // Skip if checkbox doesn't exist (DocAI disabled)
    }

    await this.startButton.click();
    return new ChooseMonthsPage(this.page).waitForURLtoMatchPagePath();
  }
}
