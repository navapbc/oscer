import { Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { DocAiActivityReviewPage } from './DocAiActivityReviewPage';

export class DocAiUploadStatusPage extends BasePage {
  get pagePath() {
    return '*document_staging/doc_ai_upload_status*';
  }

  constructor(page: Page) {
    super(page);
  }

  /**
   * Override to use 'commit' instead of the default 'load' waitUntil.
   * The upload form is Turbo-driven, so the redirect updates the URL via
   * history.pushState without firing the native 'load' event.
   */
  async waitForURLtoMatchPagePath(): Promise<typeof this> {
    await this.page.waitForURL(this.pagePath, { waitUntil: 'commit' });
    return this;
  }

  /**
   * Waits for all staged documents to finish processing.
   * The status page uses a Turbo Frame that auto-refreshes every 5 seconds.
   * When all documents are validated, the scanning modal disappears.
   */
  async waitForCompletion(timeout = 30000) {
    await this.page.locator('#scanning-modal').waitFor({ state: 'detached', timeout });
  }

  /**
   * Submits the save-form, which posts staged_document_ids to accept_doc_ai
   * and redirects to the first activity review page.
   */
  async clickSaveAndContinue() {
    await this.page.getByRole('button', { name: /save and continue/i }).click();
    return new DocAiActivityReviewPage(this.page).waitForURLtoMatchPagePath();
  }
}
