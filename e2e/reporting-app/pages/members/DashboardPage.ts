import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage';
import { BeforeYouStartPage } from './activity-reports';
import { ExemptionScreenerPage } from './exemptions';

export class DashboardPage extends BasePage {
  get pagePath() {
    return '/dashboard';
  }

  readonly reportActivitiesButton: Locator;
  readonly requestExemptionButton: Locator;
  readonly getStartedLink: Locator;

  constructor(page: Page) {
    super(page);
    // Match both old and new button text variants
    this.reportActivitiesButton = page.getByRole('link', { name: /^report activities/i });
    this.requestExemptionButton = page.getByRole('link', { name: /request exemption/i });
    // "Get started" links to the exemption screener with certification_case_id
    this.getStartedLink = page.getByRole('link', { name: /^get started$/i });
  }

  async clickReportActivities() {
    await this.reportActivitiesButton.click();
    return new BeforeYouStartPage(this.page).waitForURLtoMatchPagePath();
  }

  async clickGetStarted() {
    await this.getStartedLink.click();
    return new ExemptionScreenerPage(this.page).waitForURLtoMatchPagePath();
  }
}
