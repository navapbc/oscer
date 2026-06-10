import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { BeforeYouStartPage } from '../activity-reports';

export class ExemptionScreenerCompletePage extends BasePage {
  get pagePath() {
    return '**/exemption-screener/complete*';
  }

  readonly reportActivitiesLink: Locator;

  constructor(page: Page) {
    super(page);
    this.reportActivitiesLink = page.getByRole('link', { name: /^report activities/i });
  }

  async clickReportActivities() {
    await this.reportActivitiesLink.click();
    return new BeforeYouStartPage(this.page).waitForURLtoMatchPagePath();
  }
}
