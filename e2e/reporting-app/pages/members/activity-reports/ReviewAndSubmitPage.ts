import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ActivityReportPage } from './ActivityReportPage';

export class ReviewAndSubmitPage extends BasePage {
  get pagePath() {
    return '/activity_report_application_forms/*/review';
  }

  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.submitButton = page.getByRole('button', { name: /Submit/i });
  }

  async clickSubmit() {
    await this.submitButton.click();
    return new ActivityReportPage(this.page).waitForURLtoMatchPagePath();
  }
}
