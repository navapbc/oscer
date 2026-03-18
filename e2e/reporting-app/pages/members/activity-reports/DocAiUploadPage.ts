import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { DocAiUploadStatusPage } from './DocAiUploadStatusPage';

export class DocAiUploadPage extends BasePage {
  get pagePath() {
    return 'activity_report_application_forms/*/doc_ai_upload';
  }

  readonly fileInput: Locator;
  readonly saveAndContinueButton: Locator;

  constructor(page: Page) {
    super(page);
    this.fileInput = page.locator('input[type="file"]');
    this.saveAndContinueButton = page.getByRole('button', { name: /save and continue/i });
  }

  async uploadFiles(pdfPath: string, jpegPath: string) {
    await this.fileInput.setInputFiles([pdfPath, jpegPath]);
    await this.saveAndContinueButton.click();
    return new DocAiUploadStatusPage(this.page).waitForURLtoMatchPagePath();
  }
}
