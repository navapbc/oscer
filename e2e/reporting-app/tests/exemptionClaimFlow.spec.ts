import { expect } from '@playwright/test';
import { test } from '../../fixtures';
import { AccountCreationFlow, ExemptionClaimFlow } from '../flows';
import { CertificationRequestPage } from '../pages';

/**
 * End-to-end test: member exemption claim flow
 *
 * Happy path:
 *   1. Create a certification via the demo page (gives the member a
 *      certification case with hours_needed > 0 so the "Request exemption"
 *      button appears on the dashboard).
 *   2. Register a new account and verify it via email.
 *   3. Sign in and skip MFA.
 *   4. From the dashboard, click "Request exemption" → exemption screener.
 *   5. Work through the screener: answer "Yes" to the first question.
 *   6. On the "may qualify" page, click "Request an exemption" to create the
 *      ExemptionApplicationForm and land on the documents upload page.
 *   7. Skip document upload and click "Continue".
 *   8. On the review page, click "Submit exemption".
 *   9. Assert the URL matches /exemption_application_forms/:id (show page)
 *      and the success text is visible.
 *
 * TODOs (verify against live app before removing):
 *   - Confirm the "Request exemption" link label on the dashboard matches
 *     /request exemption/i (see new_certification.yml → request_exemption_button).
 *   - Confirm the "Start" button on the exemption screener intro page is
 *     a <link> and not a <button> (see exemption_screener/index.html.erb).
 *   - Confirm answering "Yes" to the first screener question (caregiver_disability)
 *     redirects directly to the may_qualify page (no intermediate steps).
 *   - Confirm that skipping document upload (clicking "Continue" on the
 *     documents page without uploading) is allowed before submission.
 *   - Confirm the show page displays "Your exemption is being reviewed" after
 *     a successful submit (see exemption_application_forms/en.yml → show.intro.submitted).
 */
test('exemption claim flow: member submits an exemption application', async ({
  page,
  emailService,
}) => {
  // Slow the test down — it involves email verification and multiple redirects
  test.slow();

  const email = emailService.generateEmailAddress(emailService.generateUsername());
  const password = 'testPassword';

  // Step 1: Create a certification for the member via the demo endpoint
  const certificationRequestPage = await new CertificationRequestPage(page).go();
  await certificationRequestPage.fillAndSubmit(email);

  // Step 2: Register account, verify email, get to sign-in page
  const accountCreationFlow = new AccountCreationFlow(page, emailService);
  const signInPage = await accountCreationFlow.run(email, password);

  // Step 3: Sign in and skip MFA
  const mfaPreferencePage = await signInPage.signIn(email, password);
  await mfaPreferencePage.skipMFA();

  // Steps 4-8: Run the full exemption claim flow
  const exemptionFlow = new ExemptionClaimFlow(page);
  await exemptionFlow.run();

  // Step 9: Assert we landed on the exemption show page after submission
  expect(page.url()).toContain('/exemption_application_forms/');
  expect(page.url()).not.toContain('/review');
  expect(page.url()).not.toContain('/documents');
});
