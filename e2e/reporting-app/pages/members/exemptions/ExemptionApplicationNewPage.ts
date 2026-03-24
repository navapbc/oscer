import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionApplicationTypePage } from './ExemptionApplicationTypePage';

export class ExemptionApplicationNewPage extends BasePage {
  get pagePath() {
    return '/exemption_application_forms/new*';
  }

  readonly startButton: Locator;

  constructor(page: Page) {
    super(page);
    this.startButton = page.getByRole('button', { name: /^start$/i });
  }

  async clickStart() {
    await this.startButton.click();
    return new ExemptionApplicationTypePage(this.page).waitForURLtoMatchPagePath();
  }
}
