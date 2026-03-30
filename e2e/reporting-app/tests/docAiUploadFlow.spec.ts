import path from 'path';
import { expect } from '@playwright/test';
import { test } from '../../fixtures';
import { AccountCreationFlow, DocAiUploadFlow } from '../flows';
import { CertificationRequestPage } from '../pages';

test('member can upload a payslip via DocAI and land on activity review', async ({
  page,
  emailService,
}) => {
  // DocAI processing takes ~1-2 minutes; set generous timeout for the full test
  test.setTimeout(300_000);

  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';
  const fixturePath = path.join(__dirname, '../fixtures/paystub_test_feb_2026_paydate.pdf');

  // 1. Create a certification case with a February 2026 certification date so the
  //    reporting period shown on ChooseMonthsPage is "February 2026", matching
  //    the pay date on the fixture paystub.
  const certPage = await new CertificationRequestPage(page).go();
  await certPage.fillAndSubmit(email, '02/28/2026');

  // 2. Register account + verify email
  const accountCreationFlow = new AccountCreationFlow(page, emailService);
  const signInPage = await accountCreationFlow.run(email, password);

  // 3. Sign in and skip MFA setup
  const mfaPreferencePage = await signInPage.signIn(email, password);
  await mfaPreferencePage.skipMFA();

  // 4. Run DocAI upload flow: dashboard → before-you-start (no skip_ai) →
  //    choose months (February 2026) → upload → wait for processing results
  const docAiFlow = new DocAiUploadFlow(page);
  const statusPage = await docAiFlow.run(fixturePath);

  // 5. Assert the validated document is visible in the results section
  await expect(page.getByText('paystub_test_feb_2026_paydate.pdf')).toBeVisible();

  // 6. Save and continue → accept_doc_ai creates income activities and redirects
  //    to the activity edit page for DocAI review
  await statusPage.saveAndContinue();
  await expect(page).toHaveURL(/\/activities\/.*\/edit.*doc_ai_review=true/);
});
