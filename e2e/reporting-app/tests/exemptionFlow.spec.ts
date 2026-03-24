import path from 'path';
import { expect } from '@playwright/test';

import { test } from '../../fixtures';
import { AccountCreationFlow, ExemptionFlow } from '../flows';
import { CertificationRequestPage } from '../pages';

test('Exemption application: direct form submission', async ({ page, emailService }) => {
  // Triple the default timeout due to external email verification dependency
  test.slow();

  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';

  const certificationRequestPage = await new CertificationRequestPage(page).go();
  await certificationRequestPage.fillAndSubmit(email);

  const accountCreationFlow = new AccountCreationFlow(page, emailService);
  const signInPage = await accountCreationFlow.run(email, password);
  const mfaPreferencePage = await signInPage.signIn(email, password);
  await mfaPreferencePage.skipMFA();

  const fixturePath = path.resolve(__dirname, '../fixtures/exemption_medically_frail.pdf');
  const showPage = await new ExemptionFlow(page).run(fixturePath);

  await expect(showPage.statusText).toBeVisible();
});
