import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionReviewPage } from './ExemptionReviewPage';

export class ExemptionDocumentsPage extends BasePage {
  get pagePath() {
    return '**/exemption_application_forms/*/documents';
  }

  readonly fileInput: Locator;
  readonly uploadButton: Locator;
  readonly continueLink: Locator;

  constructor(page: Page) {
    super(page);
    this.fileInput = page.getByLabel(/upload supporting document/i);
    this.uploadButton = page.getByRole('button', { name: /upload document/i });
    this.continueLink = page.getByRole('link', { name: /^continue$/i });
  }

  // Upload a file and then click "Continue" to proceed to the review page.
  // The upload POSTs to upload_documents and redirects back to this same documents page.
  async uploadAndContinue(filePath: string) {
    await this.fileInput.setInputFiles(filePath);
    await this.uploadButton.click();
    // Wait for redirect back to documents page after upload
    await this.waitForURLtoMatchPagePath();
    await this.continueLink.click();
    return new ExemptionReviewPage(this.page).waitForURLtoMatchPagePath();
  }
}
