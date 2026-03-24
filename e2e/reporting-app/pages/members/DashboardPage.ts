import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage';
import { BeforeYouStartPage } from './activity-reports';
import { ExemptionScreenerPage } from './exemptions/ExemptionScreenerPage';

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
    // "Request exemption" link shown when hours_needed > 0
    // TODO: verify exact label against live app — see new_certification.yml
    this.requestExemptionButton = page.getByRole('link', { name: /request exemption/i });
  }

  async clickReportActivities() {
    await this.reportActivitiesButton.click();
    return new BeforeYouStartPage(this.page).waitForURLtoMatchPagePath();
  }

  async clickRequestExemption() {
    await this.requestExemptionButton.click();
    return new ExemptionScreenerPage(this.page).waitForURLtoMatchPagePath();
  }
}
