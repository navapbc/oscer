import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';

export class ExemptionShowPage extends BasePage {
  get pagePath() {
    // Matches /exemption_application_forms/:id (UUID only, no sub-routes like /documents or /review)
    return '**/exemption_application_forms/*';
  }

  readonly submittedNotice: Locator;

  constructor(page: Page) {
    super(page);
    this.submittedNotice = page.getByText(/your exemption is being reviewed/i);
  }
}
