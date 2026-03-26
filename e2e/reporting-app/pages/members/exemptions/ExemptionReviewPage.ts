import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionShowPage } from './ExemptionShowPage';

export class ExemptionReviewPage extends BasePage {
  get pagePath() {
    return '**/exemption_application_forms/*/review';
  }

  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.submitButton = page.getByRole('button', { name: /submit exemption/i });
  }

  async submit() {
    await this.submitButton.click();
    return new ExemptionShowPage(this.page).waitForURLtoMatchPagePath();
  }
}
