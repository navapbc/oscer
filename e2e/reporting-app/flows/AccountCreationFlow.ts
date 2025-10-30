import { EmailAddress, EmailService } from '../../lib/services/email/EmailService';

import { Page } from '@playwright/test';
import { RegistrationPage } from '../pages/users/RegistrationPage';

export class AccountCreationFlow {
  page: Page;
  emailService: EmailService;

  constructor(page: Page, emailService: EmailService) {
    this.page = page;
    this.emailService = emailService;
  }

  async run(emailAddress: EmailAddress, password: string) {
    // Navigate to registration page and fill out registration form
    const registrationPage = await new RegistrationPage(this.page).go();
    const verifyAccountPage = await registrationPage.fillOutRegistration(emailAddress, password);

    // Get verification code and submit
    const verificationCode = await this.fetchVerificationCode(emailAddress);
    const signInPage = await verifyAccountPage.submitVerificationCode(
      emailAddress,
      verificationCode
    );

    return signInPage;
  }

  async fetchVerificationCode(emailAddress: EmailAddress): Promise<string> {
    const emailContent = await this.emailService.waitForEmailWithSubject(
      emailAddress,
      AccountCreationFlow.VERIFICATION_CODE_SUBJECT
    );
    const verificationCode = emailContent.text.match(/\b\d{6}\b/)?.[0];
    if (!verificationCode) {
      throw new Error('Failed to extract verification code from email.');
    }

    return verificationCode;
  }

  private static readonly VERIFICATION_CODE_SUBJECT = 'Your verification code';
}
