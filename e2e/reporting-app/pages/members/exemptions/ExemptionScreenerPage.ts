import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionScreenerQuestionPage } from './ExemptionScreenerQuestionPage';

export class ExemptionScreenerPage extends BasePage {
  get pagePath() {
    return '/exemption-screener*';
  }

  readonly startButton: Locator;

  constructor(page: Page) {
    super(page);
    this.startButton = page.getByRole('link', { name: /^Start$/i });
  }

  async clickStart() {
    await this.startButton.click();
    return new ExemptionScreenerQuestionPage(this.page).waitForURLtoMatchPagePath();
  }
}
