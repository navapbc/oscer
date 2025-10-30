import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ActivityReportPage } from './ActivityReportPage';

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
}
