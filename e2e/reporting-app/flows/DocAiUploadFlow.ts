import { Page } from '@playwright/test';

import { DashboardPage } from '../pages/members';
import { ActivityReportPage, ReviewAndSubmitPage } from '../pages/members/activity-reports';

const EMPLOYER_NAME = 'Test Employer Inc.';

export class DocAiUploadFlow {
  page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  /**
   * Runs the full DocAI-assisted activity report flow:
   *  1. Navigate from dashboard to "Before you start" — do NOT skip AI
   *  2. Select the February 2026 reporting period
   *  3. Upload the provided PDF and JPEG paystubs
   *  4. Wait for DocAI background job to validate staged documents
   *  5. Accept the DocAI results (creates IncomeActivities from payslips)
   *  6. Review and confirm each activity the AI created
   *  7. Review and submit the completed activity report
   */
  async run(pdfPath: string, jpegPath: string) {
    // 1. Dashboard → Before You Start (DocAI enabled — do not skip)
    const dashboardPage = new DashboardPage(this.page);
    const beforeYouStartPage = await dashboardPage.clickReportActivities();
    const chooseMonthsPage = await beforeYouStartPage.clickStart(false);

    // 2. Select the sole available month (February 2026) and proceed to upload
    const docAiUploadPage = await chooseMonthsPage.selectFirstReportingPeriodAndSaveForDocAi();

    // 3. Upload PDF and JPEG paystubs
    const docAiUploadStatusPage = await docAiUploadPage.uploadFiles(pdfPath, jpegPath);

    // 4. Submit accept_doc_ai form to create activities
    const docAiActivityReviewPage = await docAiUploadStatusPage.clickSaveAndContinue();

    // 5. Review each AI-created activity (there will be one per uploaded paystub)
    let hasMoreReviews = true;
    while (hasMoreReviews) {
      hasMoreReviews = await docAiActivityReviewPage.reviewAndConfirm(EMPLOYER_NAME);
    }

    // 6. Review and submit the activity report
    const activityReportPage = new ActivityReportPage(this.page);
    const reviewAndSubmitPage = await activityReportPage.clickReviewAndSubmit();
    await reviewAndSubmitPage.clickSubmit();

    return new ReviewAndSubmitPage(this.page);
  }
}
