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
    this.skipAiCheckbox = page.locator('.usa-checkbox__label') || page.getByLabel(/skip ai/i);
  }

  async clickStart(skipAi: boolean = true) {
    if (skipAi) {
      // Skip DocAI for the traditional manual document upload flow
      await this.skipAiCheckbox.check();
    }
    await this.startButton.click();

    return new ChooseMonthsPage(this.page).waitForURLtoMatchPagePath();
  }
}
