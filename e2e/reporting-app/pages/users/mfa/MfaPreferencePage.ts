import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { DashboardPage } from '../../members';

export class MfaPreferencePage extends BasePage {
  get pagePath() {
    return '/users/mfa/preference';
  }

  readonly skipMFAOption: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);

    // Locate the label instead of the radio option because the radio input is
    // hidden off the screen for USWDS styling purposes, so calling .check()
    // on the radio input times out waiting for the input to be visible.
    // Instead, to select the radio option we click on the label text.
    this.skipMFAOption = page.getByText(/skip/i);
    this.submitButton = page.getByRole('button', { name: /submit/i });
  }

  async skipMFA() {
    await this.skipMFAOption.click();
    await this.submitButton.click();
    return new DashboardPage(this.page).waitForURLtoMatchPagePath();
  }
}
