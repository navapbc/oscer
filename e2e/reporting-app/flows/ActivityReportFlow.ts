import { Page } from '@playwright/test';
import { DashboardPage } from '../pages/members';

export class ActivityReportFlow {
  page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async run(
    email: string,
    password: string,
    employerName: string = 'Acme Inc',
    hours: string = '80'
  ) {
    const dashboardPage = await new DashboardPage(this.page).go();
    const beforeYouStartPage = await dashboardPage.clickReportActivities();
    const chooseMonthsPage = await beforeYouStartPage.clickStart();
    const activityReportPage = await chooseMonthsPage.selectFirstReportingPeriodAndSave();
    const activityDetailsPage = await activityReportPage.clickAddActivity();
    const supportingDocumentsPage = await activityDetailsPage.fillActivityDetails(
      employerName,
      hours
    );
    const activityReportPageAfterUpload = await supportingDocumentsPage.clickContinue();
    const reviewAndSubmitPage = await activityReportPageAfterUpload.clickReviewAndSubmit();
    const finalDashboardPage = await reviewAndSubmitPage.clickSubmit();

    return finalDashboardPage;
  }
}
