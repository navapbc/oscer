import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionApplicationShowPage } from './ExemptionApplicationShowPage';

export class ExemptionApplicationReviewPage extends BasePage {
  get pagePath() {
    return '/exemption_application_forms/*/review';
  }

  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.submitButton = page.getByRole('button', { name: /submit exemption/i });
  }

  async clickSubmitExemption() {
    await this.submitButton.click();
    return new ExemptionApplicationShowPage(this.page).waitForURLtoMatchPagePath();
  }
}
