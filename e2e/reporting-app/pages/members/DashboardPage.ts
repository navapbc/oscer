import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage';
import { BeforeYouStartPage } from './activity-reports';
import { ExemptionScreenerPage } from './exemptions';

export class DashboardPage extends BasePage {
  get pagePath() {
    return '/dashboard';
  }

  readonly reportActivitiesButton: Locator;
  readonly startReportingActivitiesLink: Locator;
  readonly requestExemptionButton: Locator;
  readonly getStartedLink: Locator;

  constructor(page: Page) {
    super(page);
    this.reportActivitiesButton = page.getByRole('link', { name: /^report activities/i });
    this.startReportingActivitiesLink = page.getByRole('link', {
      name: /^start reporting activities/i,
    });
    this.requestExemptionButton = page.getByRole('link', { name: /request exemption/i });
    // "Get started" links to the exemption screener with certification_case_id
    this.getStartedLink = page.getByRole('link', { name: /^get started$/i });
  }

  async clickReportActivities() {
    if (await this.getStartedLink.isVisible()) {
      const screenerIndexPage = await this.clickGetStarted();
      const firstQuestionPage = await screenerIndexPage.clickStart();
      const completePage = await firstQuestionPage.answerNoUntilComplete();
      return completePage.clickReportActivities();
    }

    if (await this.startReportingActivitiesLink.isVisible()) {
      await this.startReportingActivitiesLink.click();
      return new BeforeYouStartPage(this.page).waitForURLtoMatchPagePath();
    }

    await this.reportActivitiesButton.click();
    return new BeforeYouStartPage(this.page).waitForURLtoMatchPagePath();
  }

  async clickGetStarted() {
    await this.getStartedLink.click();
    return new ExemptionScreenerPage(this.page).waitForURLtoMatchPagePath();
  }
}
