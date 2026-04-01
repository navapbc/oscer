import { Locator, Page } from '@playwright/test';
import { BasePage } from './BasePage';

export class CertificationRequestPage extends BasePage {
  get pagePath() {
    return '/demo/certifications/new';
  }

  readonly emailField: Locator;
  readonly firstNameField: Locator;
  readonly lastNameField: Locator;
  readonly caseNumberField: Locator;
  readonly certificationDateField: Locator;
  readonly requestCertificationButton: Locator;

  constructor(page: Page) {
    super(page);
    this.emailField = page.getByLabel('Email');
    this.firstNameField = page.getByLabel('First or given name');
    this.lastNameField = page.getByLabel('Last or family name');
    this.caseNumberField = page.getByLabel('Case number');
    this.certificationDateField = page.getByLabel('Certification date');
    this.requestCertificationButton = page.getByRole('button', { name: /Request certification/i });
  }

  async fillAndSubmit(email: string, certificationDate?: string) {
    // Generate a random 9-digit case number
    const caseNumber = String(
      Math.floor(Math.random() * (1_000_000_000 - 100_000_000)) + 100_000_000
    );

    const date = certificationDate ?? new Date().toLocaleDateString('en-US');

    await this.emailField.fill(email);
    await this.firstNameField.fill('John');
    await this.lastNameField.fill('Doe');
    await this.caseNumberField.fill(caseNumber);
    await this.certificationDateField.fill(date);
    await this.requestCertificationButton.click();
  }
}
