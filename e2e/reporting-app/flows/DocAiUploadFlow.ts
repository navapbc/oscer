import { Page } from '@playwright/test';
import { DashboardPage } from '../pages/members';
import { DocAiStatusPage } from '../pages/members/activity-reports/DocAiStatusPage';

export class DocAiUploadFlow {
  constructor(private readonly page: Page) {}

  // Runs the DocAI upload flow from the dashboard to the status results page.
  // Caller should assert the final URL after accept_doc_ai redirects.
  async run(fixturePath: string, reportingPeriod: string = 'February 2026'): Promise<DocAiStatusPage> {
    // 1. Navigate to the activity report new form without skipping DocAI
    const dashboard = await new DashboardPage(this.page).go();
    const beforeYouStartPage = await dashboard.clickReportActivities();
    const chooseMonthsPage = await beforeYouStartPage.clickStartWithDocAi();

    // 2. Select the reporting period — update action redirects to doc_ai_upload
    const docAiUploadPage = await chooseMonthsPage.selectMonthAndSave(reportingPeriod);

    // 3. Upload the fixture file and wait for the status page
    const statusPage = await docAiUploadPage.uploadFile(fixturePath);

    // 4. Wait for DocAI processing to complete (~1-2 minutes)
    await statusPage.waitForResults();

    return statusPage;
  }
}
