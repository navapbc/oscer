import path from 'path';

import { Page } from '@playwright/test';

import {
  ActivityDetailsPage,
  ActivityReportPage,
  ActivityTypePage,
  BeforeYouStartPage,
  ChooseMonthsPage,
  SupportingDocumentsPage,
} from '../pages/members/activity-reports';
import { DashboardPage } from '../pages/members/DashboardPage';
import {
  ExemptionDocumentsPage,
  ExemptionMayQualifyPage,
  ExemptionReviewPage,
  ExemptionScreenerCompletePage,
  ExemptionScreenerPage,
  ExemptionScreenerQuestionPage,
} from '../pages/members/exemptions';
import { NetworkProfile } from './NetworkProfiles';
import { PageMeasurement, PerfCollector } from './PerfCollector';

const FIXTURES = path.resolve(__dirname, '../fixtures');
export const ACTIVITY_PDF = path.join(FIXTURES, 'paystub_test_feb_2026_paydate.pdf');
export const EXEMPTION_PDF = path.join(FIXTURES, 'exemption_medically_frail.pdf');

type Measure = (name: string, action: () => Promise<void>) => Promise<PageMeasurement>;

function makeMeasure(collector: PerfCollector, profile: NetworkProfile): Measure {
  return (name, action) => collector.measureAction(name, profile, action);
}

/**
 * Manual-walk match: No through entire exemption screener → 2 hours activities
 * (with supporting docs) → 1 income activity with supporting doc → submit.
 * Uses classic (non-DocAI) activity report upload.
 */
export async function runAllNoScreenerActivitiesFlow(
  page: Page,
  collector: PerfCollector,
  profile: NetworkProfile
): Promise<PageMeasurement[]> {
  const measure = makeMeasure(collector, profile);
  const out: PageMeasurement[] = [];

  const dashboard = await new DashboardPage(page).go();

  out.push(
    await measure('Dashboard → screener index', async () => {
      await dashboard.clickGetStarted();
    })
  );

  out.push(
    await measure('Screener index → Start', async () => {
      await new ExemptionScreenerPage(page).clickStart();
    })
  );

  let question = 1;
  while (!page.url().includes('/exemption-screener/complete')) {
    const n = question;
    out.push(
      await measure(`Screener No #${n}`, async () => {
        const q = new ExemptionScreenerQuestionPage(page);
        await q.noRadio.dispatchEvent('click');
        await q.continueButton.click();
        await page.waitForURL(/exemption-screener\/(question|complete)/);
      })
    );
    question += 1;
    if (question > 20) {
      throw new Error('Screener No loop exceeded 20 steps — aborting');
    }
  }

  out.push(
    await measure('Screener complete → Report activities', async () => {
      await new ExemptionScreenerCompletePage(page).clickReportActivities();
    })
  );

  out.push(
    await measure('Before you start → Skip AI / Start', async () => {
      await new BeforeYouStartPage(page).clickStart();
    })
  );

  out.push(
    await measure('Choose months → save', async () => {
      await new ChooseMonthsPage(page).selectFirstReportingPeriodAndSave();
    })
  );

  let report = new ActivityReportPage(page);

  out.push(
    await measure('Add hours activity #1 (type)', async () => {
      const type = await report.clickAddActivity();
      await type.fillHoursEducationActivityType();
    })
  );
  out.push(
    await measure('Hours activity #1 details', async () => {
      await new ActivityDetailsPage(page).fillActivityDetails('Org A', '40');
    })
  );
  out.push(
    await measure('Hours activity #1 upload_documents', async () => {
      await new SupportingDocumentsPage(page).uploadDocument(ACTIVITY_PDF);
    })
  );
  out.push(
    await measure('Hours activity #1 docs continue', async () => {
      report = await new SupportingDocumentsPage(page).clickContinue();
    })
  );

  out.push(
    await measure('Add hours activity #2 (type)', async () => {
      const type = await report.clickAddActivity();
      await type.fillHoursEducationActivityType();
    })
  );
  out.push(
    await measure('Hours activity #2 details', async () => {
      await new ActivityDetailsPage(page).fillActivityDetails('Org B', '40');
    })
  );
  out.push(
    await measure('Hours activity #2 upload_documents', async () => {
      await new SupportingDocumentsPage(page).uploadDocument(ACTIVITY_PDF);
    })
  );
  out.push(
    await measure('Hours activity #2 docs continue', async () => {
      report = await new SupportingDocumentsPage(page).clickContinue();
    })
  );

  out.push(
    await measure('Add income activity (type)', async () => {
      await report.clickAddActivity();
      await new ActivityTypePage(page).fillIncomeEmploymentActivityType();
    })
  );
  out.push(
    await measure('Income activity details', async () => {
      await new ActivityDetailsPage(page).fillIncomeActivityDetails('Employer Inc', '1500');
    })
  );
  out.push(
    await measure('Income activity upload_documents', async () => {
      await new SupportingDocumentsPage(page).uploadDocument(ACTIVITY_PDF);
    })
  );
  out.push(
    await measure('Income activity docs continue', async () => {
      report = await new SupportingDocumentsPage(page).clickContinue();
    })
  );

  out.push(
    await measure('Review and submit', async () => {
      const review = await report.clickReviewAndSubmit();
      await review.clickSubmit();
    })
  );

  return out;
}

/**
 * Medical exemption Yes path with regular (non-DocAI) document upload.
 * No ×2 → Yes medical_condition → upload → submit.
 */
export async function runMedicalExemptionYesFlow(
  page: Page,
  collector: PerfCollector,
  profile: NetworkProfile
): Promise<PageMeasurement[]> {
  const measure = makeMeasure(collector, profile);
  const out: PageMeasurement[] = [];

  const dashboard = await new DashboardPage(page).go();

  out.push(
    await measure('Dashboard → screener index', async () => {
      await dashboard.clickGetStarted();
    })
  );

  out.push(
    await measure('Screener index → Start', async () => {
      await new ExemptionScreenerPage(page).clickStart();
    })
  );

  out.push(
    await measure('Screener No #1 (caregiver_disability)', async () => {
      await new ExemptionScreenerQuestionPage(page).answerNo();
    })
  );

  out.push(
    await measure('Screener No #2 (caregiver_child)', async () => {
      await new ExemptionScreenerQuestionPage(page).answerNo();
    })
  );

  out.push(
    await measure('Screener Yes (medical_condition)', async () => {
      await new ExemptionScreenerQuestionPage(page).answerYes();
    })
  );

  out.push(
    await measure('May qualify → Request exemption', async () => {
      await new ExemptionMayQualifyPage(page).clickRequestExemption();
    })
  );

  out.push(
    await measure('Exemption upload_documents', async () => {
      const docs = new ExemptionDocumentsPage(page);
      await docs.fileInput.setInputFiles(EXEMPTION_PDF);
      await docs.uploadButton.click();
      await docs.waitForURLtoMatchPagePath();
    })
  );

  out.push(
    await measure('Exemption docs → Continue', async () => {
      const docs = new ExemptionDocumentsPage(page);
      await docs.continueLink.click();
      await new ExemptionReviewPage(page).waitForURLtoMatchPagePath();
    })
  );

  out.push(
    await measure('Exemption review → Submit', async () => {
      await new ExemptionReviewPage(page).submit();
    })
  );

  return out;
}
