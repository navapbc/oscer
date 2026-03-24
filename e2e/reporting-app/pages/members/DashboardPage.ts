import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage';
import { BeforeYouStartPage } from './activity-reports';
import { ExemptionApplicationNewPage } from './exemptions';

export class DashboardPage extends BasePage {
  get pagePath() {
    return '/dashboard';
  }

  readonly reportActivitiesButton: Locator;
  readonly requestExemptionButton: Locator;

  constructor(page: Page) {
    super(page);
    // Match both old and new button text variants
    this.reportActivitiesButton = page.getByRole('link', { name: /^report activities/i });
    this.requestExemptionButton = page.getByRole('link', { name: /request exemption/i });
  }

  async clickReportActivities() {
    await this.reportActivitiesButton.click();
    return new BeforeYouStartPage(this.page).waitForURLtoMatchPagePath();
  }

  async clickRequestExemption() {
    await this.requestExemptionButton.click();
    return new ExemptionApplicationNewPage(this.page).waitForURLtoMatchPagePath();
  }
}
