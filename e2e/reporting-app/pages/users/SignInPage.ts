import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage';
import { MfaPreferencePage } from './mfa/MfaPreferencePage';
import { DashboardPage } from '../members/DashboardPage';

export class SignInPage extends BasePage {
  get pagePath() {
    return '/users/sign_in';
  }

  readonly emailField: Locator;
  readonly passwordField: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.emailField = page.getByLabel('Email');
    this.passwordField = page.getByLabel('Password');
    this.submitButton = page.getByRole('button', { name: /Sign in/i });
  }

  async signIn(emailAddress: string, password: string) {
    await this.emailField.fill(emailAddress);
    await this.passwordField.fill(password);
    await this.submitButton.click();

    // First login will always go to the MFA Preference page.
    return new MfaPreferencePage(this.page).waitForURLtoMatchPagePath();
  }
}
