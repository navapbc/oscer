import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage';
import { VerifyAccountPage } from './VerifyAccountPage';

export class RegistrationPage extends BasePage {
  get pagePath() {
    return '/users/registrations';
  }

  readonly emailField: Locator;
  readonly passwordField: Locator;
  readonly passwordConfirmationField: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.emailField = page.getByLabel('Email');
    this.passwordField = page.getByLabel('Password', { exact: true });
    this.passwordConfirmationField = page.getByLabel('Password confirmation');
    this.submitButton = page.getByRole('button', { name: /Create/i });
  }

  async fillOutRegistration(emailAddress: string, password: string) {
    await this.emailField.fill(emailAddress);
    await this.passwordField.fill(password);
    await this.passwordConfirmationField.fill(password);
    await this.submitButton.click();
    return new VerifyAccountPage(this.page).waitForURLtoMatchPagePath();
  }
}
