import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionDocumentsPage } from './ExemptionDocumentsPage';

export class ExemptionMayQualifyPage extends BasePage {
  get pagePath() {
    return '**/exemption-screener/may-qualify/**';
  }

  readonly requestExemptionButton: Locator;

  constructor(page: Page) {
    super(page);
    this.requestExemptionButton = page.getByRole('button', { name: /request an exemption/i });
  }

  async clickRequestExemption() {
    await this.requestExemptionButton.click();
    return new ExemptionDocumentsPage(this.page).waitForURLtoMatchPagePath();
  }
}
