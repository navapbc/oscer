import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ActivityReportPage } from './ActivityReportPage';

export class SupportingDocumentsPage extends BasePage {
  get pagePath() {
    return 'activity_report_application_forms/*/activities/*/documents';
  }

  readonly fileInput: Locator;
  readonly uploadButton: Locator;
  readonly continueButton: Locator;

  constructor(page: Page) {
    super(page);
    this.fileInput = page.locator('input[type="file"]');
    this.uploadButton = page.getByRole('button', { name: /upload document/i });
    this.continueButton = page.getByRole('link', { name: /continue/i });
  }

  /** Upload a supporting document (POST upload_documents → redirect back here). */
  async uploadDocument(filePath: string) {
    await this.fileInput.setInputFiles(filePath);
    await this.uploadButton.click();
    await this.waitForURLtoMatchPagePath();
    return this;
  }

  async clickContinue() {
    await this.continueButton.click();
    return new ActivityReportPage(this.page).waitForURLtoMatchPagePath();
  }
}
