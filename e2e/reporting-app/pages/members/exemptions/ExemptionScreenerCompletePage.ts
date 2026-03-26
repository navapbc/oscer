import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';

export class ExemptionScreenerCompletePage extends BasePage {
  get pagePath() {
    return '**/exemption-screener/complete?*';
  }

  readonly heading: Locator;
  readonly reportActivitiesLink: Locator;
  readonly startOverLink: Locator;

  constructor(page: Page) {
    super(page);
    this.heading = page.getByRole('heading', { name: /no exemptions apply/i });
    this.reportActivitiesLink = page.getByRole('link', { name: /report activities/i });
    this.startOverLink = page.getByRole('link', { name: /start over/i });
  }
}
