import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionSubmittedPage } from './ExemptionSubmittedPage';

export class ExemptionReviewPage extends BasePage {
  get pagePath() {
    return '/exemption_application_forms/*/review';
  }

  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.submitButton = page.getByRole('button', { name: /^Submit exemption$/i });
  }

  async clickSubmit() {
    await this.submitButton.click();
    return new ExemptionSubmittedPage(this.page).waitForURLtoMatchPagePath();
  }
}
