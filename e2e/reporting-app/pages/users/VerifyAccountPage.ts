import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage';
import { SignInPage } from './SignInPage';

export class VerifyAccountPage extends BasePage {
  get pagePath() {
    return '/users/verify-account';
  }

  readonly verifyYourEmailHeader: Locator;
  readonly emailField: Locator;
  readonly codeField: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.verifyYourEmailHeader = page.locator('h1');
    this.emailField = page.getByLabel('Email');
    this.codeField = page.getByLabel('code');
    this.submitButton = page.getByRole('button', { name: /verify/i });
  }

  async submitVerificationCode(emailAddress: string, code: string) {
    await this.emailField.fill(emailAddress);
    await this.codeField.fill(code);
    await this.submitButton.click();
    return new SignInPage(this.page).waitForURLtoMatchPagePath();
  }
}
