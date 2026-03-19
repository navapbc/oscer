import path from 'path';

import { expect } from '@playwright/test';

import { test } from '../../fixtures';
import { CertificationRequestPage } from '../pages';
import { AccountCreationFlow, DocAiUploadFlow } from '../flows';

/**
 * DocAI upload integration test
 *
 * Creates a certification with a February 2026 certification date and a
 * 1-month look-back period so that February 2026 is the sole selectable
 * reporting period.  Two paystubs from that pay period (one PDF, one JPEG)
 * are uploaded; the mock DocAI server (started by Playwright's webServer config)
 * responds immediately so GoodJob validates staged documents within ~1 second.
 * After accept_doc_ai creates IncomeActivities from the validated
 * payslips, the test walks through reviewing and confirming each AI-created
 * activity before submitting the completed report.
 */
test('DocAI upload: paystubs are read and activity is created for the upload period', async ({
  page,
  emailService,
}) => {
  test.slow();

  // February 2026 certification date with the default lookback of 1 and
  // number_of_months_to_certify of 1 means "February 2026" is the only
  // available reporting month — matching the pay date in both fixture files.
  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';
  const certificationDate = '2/15/2026'; // M/D/YYYY — matches en-US locale format

  // ── Step 1: Create a certification request ──────────────────────────────
  const certificationRequestPage = await new CertificationRequestPage(page).go();
  await certificationRequestPage.fillAndSubmit(email, { certificationDate });

  // ── Step 2: Sign in ──────────────────────────────────────────────────────
  const accountCreationFlow = new AccountCreationFlow(page, emailService);
  const signInPage = await accountCreationFlow.run(email, password);
  const mfaPreferencePage = await signInPage.signIn(email, password);
  await mfaPreferencePage.skipMFA();

  // ── Step 3: Run the DocAI upload flow ───────────────────────────────────
  // Fixture paths
  const pdfPath = path.resolve(__dirname, '../fixtures/paystub_test_feb_2026_paydate.pdf');
  const jpegPath = path.resolve(__dirname, '../fixtures/paystub_feb2026.jpg');

  const flow = new DocAiUploadFlow(page);
  await flow.run(pdfPath, jpegPath);

  // ── Assertions ──────────────────────────────────────────────────────────
  // After submission the controller redirects back to the activity report
  // show page (same URL pattern used by ActivityReportPage).
  expect(page.url()).toMatch(/activity_report_application_forms/);
});
