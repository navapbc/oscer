import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionReviewPage } from './ExemptionReviewPage';

export class ExemptionDocumentsPage extends BasePage {
  get pagePath() {
    return '/exemption_application_forms/*/documents';
  }

  readonly continueButton: Locator;

  constructor(page: Page) {
    super(page);
    // "Continue" link that skips document upload and navigates to the review page
    this.continueButton = page.getByRole('link', { name: /^Continue$/i });
  }

  /**
   * Clicks the "Continue" link to proceed to the review-and-submit step
   * without uploading any supporting documents.
   *
   * TODO: Add an uploadDocument(filePath) method if tests need to cover
   * the document upload step.
   */
  async clickContinue() {
    await this.continueButton.click();
    return new ExemptionReviewPage(this.page).waitForURLtoMatchPagePath();
  }
}
