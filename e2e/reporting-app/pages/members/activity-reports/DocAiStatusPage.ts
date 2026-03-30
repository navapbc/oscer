import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';

export class DocAiStatusPage extends BasePage {
  get pagePath() {
    return '**/document_staging/doc_ai_upload_status*';
  }

  readonly processingTitle: Locator;
  readonly selectedFilesSection: Locator;
  readonly saveButton: Locator;

  constructor(page: Page) {
    super(page);
    this.processingTitle = page.getByText(/your document is being checked/i);
    this.selectedFilesSection = page.locator('[data-controller="file-list"]');
    this.saveButton = page.getByRole('button', { name: /save and continue/i });
  }

  // Waits for DocAI processing to complete (processing modal disappears, results appear).
  // DocAI processing takes ~1-2 minutes; use a generous timeout.
  async waitForResults(timeout = 180_000): Promise<void> {
    await this.selectedFilesSection.waitFor({ timeout });
  }

  async saveAndContinue(): Promise<void> {
    await this.saveButton.click();
  }
}
