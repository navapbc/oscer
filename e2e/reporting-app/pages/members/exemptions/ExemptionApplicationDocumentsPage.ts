import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionApplicationReviewPage } from './ExemptionApplicationReviewPage';

export class ExemptionApplicationDocumentsPage extends BasePage {
  get pagePath() {
    return '/exemption_application_forms/*/documents';
  }

  readonly fileInput: Locator;
  readonly uploadButton: Locator;
  readonly continueLink: Locator;

  constructor(page: Page) {
    super(page);
    this.fileInput = page.locator('input[type="file"]');
    this.uploadButton = page.getByRole('button', { name: /upload document/i });
    this.continueLink = page.getByRole('link', { name: /^continue$/i });
  }

  async uploadAndContinue(fixturePath: string) {
    await this.fileInput.setInputFiles(fixturePath);
    await this.uploadButton.click();
    await this.page.waitForLoadState('networkidle');
    await this.continueLink.click();
    return new ExemptionApplicationReviewPage(this.page).waitForURLtoMatchPagePath();
  }
}
