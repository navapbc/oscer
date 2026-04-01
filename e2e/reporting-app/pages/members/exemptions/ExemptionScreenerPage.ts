import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionScreenerQuestionPage } from './ExemptionScreenerQuestionPage';

export class ExemptionScreenerPage extends BasePage {
  get pagePath() {
    return '**/exemption-screener?*';
  }

  readonly startLink: Locator;

  constructor(page: Page) {
    super(page);
    this.startLink = page.getByRole('link', { name: /^start$/i });
  }

  async clickStart() {
    await this.startLink.click();
    return new ExemptionScreenerQuestionPage(this.page).waitForURLtoMatchPagePath();
  }
}
