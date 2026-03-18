import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ActivityReportPage } from './ActivityReportPage';
import { DocAiUploadPage } from './DocAiUploadPage';

export class ChooseMonthsPage extends BasePage {
  get pagePath() {
    return '/activity_report_application_forms/*/edit';
  }

  readonly reportingPeriodCheckboxes: Locator;
  readonly saveButton: Locator;

  constructor(page: Page) {
    super(page);
    // With USADS styling, the checkbox input is hidden, so we target the label
    this.reportingPeriodCheckboxes = page.locator('.usa-checkbox__label');
    this.saveButton = page.getByRole('button', { name: /Save/i });
  }

  async selectFirstReportingPeriodAndSave() {
    // Click the first checkbox label (e.g., "October 2025")
    await this.reportingPeriodCheckboxes.first().check();
    await this.saveButton.click();
    return new ActivityReportPage(this.page).waitForURLtoMatchPagePath();
  }

  /**
   * Selects the first reporting period and saves when the DocAI flow is active.
   * With DocAI enabled and skip_ai=false, the controller redirects to the
   * doc_ai_upload page instead of the activity report page.
   */
  async selectFirstReportingPeriodAndSaveForDocAi() {
    await this.reportingPeriodCheckboxes.first().check();
    await this.saveButton.click();
    return new DocAiUploadPage(this.page).waitForURLtoMatchPagePath();
  }
}
