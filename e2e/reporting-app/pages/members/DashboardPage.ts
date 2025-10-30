import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage';
import { BeforeYouStartPage } from './activity-reports';

export class DashboardPage extends BasePage {
  get pagePath() {
    return '/dashboard';
  }

  readonly reportActivitiesButton: Locator;

  constructor(page: Page) {
    super(page);
    this.reportActivitiesButton = page.getByRole('link', { name: /^report activities$/i });
  }

  async clickReportActivities() {
    await this.reportActivitiesButton.click();
    return new BeforeYouStartPage(this.page).waitForURLtoMatchPagePath();
  }
}
