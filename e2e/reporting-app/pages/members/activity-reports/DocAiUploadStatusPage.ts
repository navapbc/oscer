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
   * Extracts the staged document IDs from the current URL query string.
   */
  getStagedDocumentIds(): string[] {
    const url = new URL(this.page.url());
    return url.searchParams.getAll('ids[]');
  }

  /**
   * Stubs the staged document status by calling the demo validate endpoint.
   * This immediately marks all pending staged documents as validated with
   * mock February 2026 payslip data, bypassing the real DocAI async processing.
   */
  async stubValidateDocuments() {
    const ids = this.getStagedDocumentIds();
    const formBody = ids.map((id) => `ids[]=${encodeURIComponent(id)}`).join('&');

    await this.page.request.post('/demo/document_staging/validate', {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      data: formBody,
    });

    // Reload so the page fetches the now-validated status from the DB
    await this.page.reload();
    await this.page.waitForLoadState('networkidle');
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
