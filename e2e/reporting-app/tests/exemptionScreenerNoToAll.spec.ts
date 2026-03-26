import { expect } from '@playwright/test';

import { test } from '../../fixtures';
import { AccountCreationFlow, ExemptionApplicationFlow } from '../flows';
import { CertificationRequestPage } from '../pages';

test('member answers no to all exemption screener questions and is directed to report activities', async ({
  page,
  emailService,
}) => {
  test.slow();

  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';

  // 1. Create a certification case via the demo endpoint
  const certPage = await new CertificationRequestPage(page).go();
  await certPage.fillAndSubmit(email);

  // 2. Register account + verify email
  const accountCreationFlow = new AccountCreationFlow(page, emailService);
  const signInPage = await accountCreationFlow.run(email, password);

  // 3. Sign in and skip MFA setup
  const mfaPreferencePage = await signInPage.signIn(email, password);
  await mfaPreferencePage.skipMFA();

  // 4. Answer "No" to all 7 screener questions
  const exemptionFlow = new ExemptionApplicationFlow(page);
  const completePage = await exemptionFlow.runNoToAll();

  // 5. Assert the complete page confirms no exemptions apply and prompts activity reporting
  await expect(completePage.heading).toBeVisible();
  expect(page.url()).toContain('/exemption-screener/complete');
});
