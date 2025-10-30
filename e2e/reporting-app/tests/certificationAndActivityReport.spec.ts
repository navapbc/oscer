import { expect } from '@playwright/test';

import { test } from '../../fixtures';
import { AccountCreationFlow, ActivityReportFlow } from '../flows';
import { CertificationRequestPage, MfaPreferencePage, StaffDashboardPage } from '../pages';

test('Certification request and activity report flow', async ({ page, emailService }) => {
  // Triple the default timeout for this test due
  // to external email verification code dependency
  test.slow();

  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';

  const certificationRequestPage = await new CertificationRequestPage(page).go();
  await certificationRequestPage.fillAndSubmit(email);

  const accountCreationFlow = new AccountCreationFlow(page, emailService);
  const signInPage = await accountCreationFlow.run(email, password);
  const mfaPreferencePage = await signInPage.signIn(email, password);
  await mfaPreferencePage.skipMFA();

  const activityReportFlow = new ActivityReportFlow(page);
  await activityReportFlow.run(email, password, 'Acme Inc', '80');

  const staffDashboardPage = await new StaffDashboardPage(page).go();

  expect(page.url()).toContain('/staff');
});
