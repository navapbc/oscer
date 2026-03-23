import { setTimeout as delay } from 'node:timers/promises';

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
   * Waits for all staged documents to finish processing.
   * Waits a fixed 90s (DocAI + polling), reloads the page, then waits until the
   * results partial renders at least one file card (processing complete).
   */
  async waitForURLtoMatchPagePath(): Promise<typeof this> {
    await delay(90_000);
    await this.page.reload({ waitUntil: 'load' });
    return this;
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
