import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';

export class ExemptionApplicationShowPage extends BasePage {
  get pagePath() {
    return '/exemption_application_forms/*';
  }

  readonly statusText: Locator;

  constructor(page: Page) {
    super(page);
    this.statusText = page.getByText('Your exemption is being reviewed');
  }
}
