import { Page } from '@playwright/test';
import { DashboardPage } from '../pages/members/DashboardPage';
import { ExemptionShowPage } from '../pages/members/exemptions';

/**
 * Orchestrates the full exemption application flow for the medical_condition type:
 *   Dashboard → Screener index → 2× "No" → "Yes" → May qualify → Documents → Review → Show
 *
 * The screener asks questions in type order (caregiver_disability, caregiver_child,
 * medical_condition, …). To land on medical_condition, we answer "No" twice then "Yes".
 */
export class ExemptionApplicationFlow {
  constructor(private readonly page: Page) {}

  async run(fixturePath: string): Promise<ExemptionShowPage> {
    // 1. Navigate to dashboard and click "Get started" to enter the screener
    const dashboard = await new DashboardPage(this.page).go();
    const screenerIndexPage = await dashboard.clickGetStarted();

    // 2. Click "Start" on the screener landing page
    const firstQuestionPage = await screenerIndexPage.clickStart();

    // 3. Answer "No" to caregiver_disability
    const secondQuestionPage = await firstQuestionPage.answerNo();

    // 4. Answer "No" to caregiver_child
    const thirdQuestionPage = await secondQuestionPage.answerNo();

    // 5. Answer "Yes" to medical_condition → lands on may_qualify
    const mayQualifyPage = await thirdQuestionPage.answerYes();

    // 6. Click "Request an exemption" → redirected to documents upload page
    const documentsPage = await mayQualifyPage.clickRequestExemption();

    // 7. Upload fixture file and continue to review page
    const reviewPage = await documentsPage.uploadAndContinue(fixturePath);

    // 8. Submit the exemption → redirected to show page
    return reviewPage.submit();
  }
}
