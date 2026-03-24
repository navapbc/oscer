import { Page } from '@playwright/test';

import { DashboardPage } from '../pages/members/DashboardPage';
import { ExemptionScreenerPage } from '../pages/members/exemptions/ExemptionScreenerPage';
import { ExemptionScreenerQuestionPage } from '../pages/members/exemptions/ExemptionScreenerQuestionPage';
import { ExemptionMayQualifyPage } from '../pages/members/exemptions/ExemptionMayQualifyPage';
import { ExemptionDocumentsPage } from '../pages/members/exemptions/ExemptionDocumentsPage';
import { ExemptionReviewPage } from '../pages/members/exemptions/ExemptionReviewPage';
import { ExemptionSubmittedPage } from '../pages/members/exemptions/ExemptionSubmittedPage';

/**
 * Orchestrates the full happy-path exemption claim flow:
 *
 *   Dashboard
 *     → "Request exemption" button
 *     → Exemption screener index (intro page)
 *     → Screener question page (answer "Yes" to first question)
 *     → "May qualify" confirmation page
 *     → Click "Request an exemption" (creates ExemptionApplicationForm)
 *     → Documents upload page (skip upload, click "Continue")
 *     → Review and submit page
 *     → Submit → ExemptionApplicationForm show page
 *
 * Prerequisites: the caller must already be signed in and on the dashboard.
 *
 * TODO: The dashboard "Request exemption" button is only shown when the user
 * has a certification with hours_needed > 0. Ensure the test sets up a
 * certification before running this flow.
 */
export class ExemptionClaimFlow {
  page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async run(): Promise<ExemptionSubmittedPage> {
    // Step 1: Navigate to dashboard and click "Request exemption"
    const dashboardPage = await new DashboardPage(this.page).go();
    await dashboardPage.clickRequestExemption();

    // Step 2: Screener intro — click "Start"
    const screenerPage = new ExemptionScreenerPage(this.page);
    await screenerPage.waitForURLtoMatchPagePath();
    await screenerPage.clickStart();

    // Step 3: Screener question — answer "Yes" to qualify
    const questionPage = new ExemptionScreenerQuestionPage(this.page);
    await questionPage.waitForURLtoMatchPagePath();
    await questionPage.answerYesAndContinue();

    // Step 4: "May qualify" page — request the exemption
    const mayQualifyPage = new ExemptionMayQualifyPage(this.page);
    await mayQualifyPage.waitForURLtoMatchPagePath();
    await mayQualifyPage.requestExemption();

    // Step 5: Documents page — skip upload, click Continue
    const documentsPage = new ExemptionDocumentsPage(this.page);
    await documentsPage.waitForURLtoMatchPagePath();
    await documentsPage.clickContinue();

    // Step 6: Review and submit
    const reviewPage = new ExemptionReviewPage(this.page);
    await reviewPage.waitForURLtoMatchPagePath();
    await reviewPage.clickSubmit();

    // Step 7: Confirm we landed on the submitted/show page
    return new ExemptionSubmittedPage(this.page).waitForURLtoMatchPagePath();
  }
}
