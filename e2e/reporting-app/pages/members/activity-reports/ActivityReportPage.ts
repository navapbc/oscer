import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ActivityDetailsPage } from './ActivityDetailsPage';
import { ReviewAndSubmitPage } from './ReviewAndSubmitPage';

export class ActivityReportPage extends BasePage {
  get pagePath() {
    return '/activity_report_application_forms/*';
  }

  readonly addActivityButton: Locator;
  readonly reviewAndSubmitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.addActivityButton = page.getByRole('link', { name: /add activity/i });
    this.reviewAndSubmitButton = page.getByRole('link', { name: /review and submit/i });
  }

  async clickAddActivity() {
    await this.addActivityButton.click();
    return new ActivityDetailsPage(this.page).waitForURLtoMatchPagePath();
  }

  async clickReviewAndSubmit() {
    await this.reviewAndSubmitButton.click();
    return new ReviewAndSubmitPage(this.page).waitForURLtoMatchPagePath();
  }
}
