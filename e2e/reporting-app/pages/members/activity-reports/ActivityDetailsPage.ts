import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { SupportingDocumentsPage } from './SupportingDocumentsPage';

export class ActivityDetailsPage extends BasePage {
  get pagePath() {
    return '/activity_report_application_forms/*/activities/new';
  }

  readonly employerNameField: Locator;
  readonly hoursField: Locator;
  readonly monthField: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.employerNameField = page.getByLabel('Employer name');
    this.hoursField = page.getByLabel('Hours');
    this.monthField = page.getByLabel('Month');
    this.submitButton = page.getByRole('button', { name: /save and continue/i });
  }

  async fillActivityDetails(employerName: string, hours: string) {
    await this.employerNameField.fill(employerName);
    await this.monthField.selectOption({ index: 1 });
    await this.hoursField.fill(hours);
    await this.submitButton.click();
    return new SupportingDocumentsPage(this.page).waitForURLtoMatchPagePath();
  }
}
