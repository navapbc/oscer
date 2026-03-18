import { Page } from '@playwright/test';
import { BasePage } from '../../BasePage';

export class DocAiActivityReviewPage extends BasePage {
  /**
   * Matches the edit activity path with doc_ai_review query param.
   * e.g. /activity_report_application_forms/{id}/activities/{id}/edit?doc_ai_review=true
   */
  get pagePath() {
    return 'activity_report_application_forms/*/activities/*/edit*';
  }

  constructor(page: Page) {
    super(page);
  }

  /**
   * Fills in the organization name (not auto-populated by DocAI), then submits
   * the review form. Returns true if more activity reviews remain, false when
   * the last activity has been confirmed and we are redirected to the activity
   * report page.
   */
  async reviewAndConfirm(organizationName: string): Promise<boolean> {
    await this.page.getByLabel('Organization name').fill(organizationName);
    await this.page.getByRole('button', { name: /save and continue/i }).click();
    await this.page.waitForLoadState('networkidle');

    // Still on an activity review page if the URL contains doc_ai_review
    return this.page.url().includes('doc_ai_review');
  }
}
