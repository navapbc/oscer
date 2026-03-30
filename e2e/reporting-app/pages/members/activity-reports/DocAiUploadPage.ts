import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { DocAiStatusPage } from './DocAiStatusPage';

export class DocAiUploadPage extends BasePage {
  get pagePath() {
    return '**/activity_report_application_forms/*/doc_ai_upload';
  }

  readonly fileInput: Locator;
  readonly saveButton: Locator;

  constructor(page: Page) {
    super(page);
    this.fileInput = page.locator('input[type="file"]');
    this.saveButton = page.getByRole('button', { name: /save and continue/i });
  }

  async uploadFile(filePath: string): Promise<DocAiStatusPage> {
    await this.fileInput.setInputFiles(filePath);
    await this.saveButton.click();
    return new DocAiStatusPage(this.page).waitForURLtoMatchPagePath();
  }
}
