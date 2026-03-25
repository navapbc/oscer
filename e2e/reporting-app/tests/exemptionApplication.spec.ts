import path from 'path';

import { expect } from '@playwright/test';

import { test } from '../../fixtures';
import { AccountCreationFlow, ExemptionApplicationFlow } from '../flows';
import { CertificationRequestPage } from '../pages';

test('member can apply for a medical exemption and submit the application', async ({
  page,
  emailService,
}) => {
  // Triple timeout — this test waits for an external email verification code
  test.slow();

  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';
  const fixturePath = path.join(__dirname, '../fixtures/exemption_medically_frail.pdf');

  // 1. Create a certification case via the demo endpoint
  const certPage = await new CertificationRequestPage(page).go();
  await certPage.fillAndSubmit(email);

  // 2. Register account + verify email
  const accountCreationFlow = new AccountCreationFlow(page, emailService);
  const signInPage = await accountCreationFlow.run(email, password);

  // 3. Sign in and skip MFA setup
  const mfaPreferencePage = await signInPage.signIn(email, password);
  await mfaPreferencePage.skipMFA();

  // 4. Run the exemption application flow (screener → medical_condition → upload → submit)
  const exemptionFlow = new ExemptionApplicationFlow(page);
  await exemptionFlow.run(fixturePath);

  // 5. Assert the show page confirms the exemption is under review
  expect(page.url()).toContain('/exemption_application_forms/');
  await expect(page.getByText(/your exemption is being reviewed/i)).toBeVisible();
});
