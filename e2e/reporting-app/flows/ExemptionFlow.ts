import { Page } from '@playwright/test';

import { DashboardPage } from '../pages/members';
import { ExemptionApplicationShowPage } from '../pages/members/exemptions';

export class ExemptionFlow {
  page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async run(fixturePath: string): Promise<ExemptionApplicationShowPage> {
    const dashboardPage = await new DashboardPage(this.page).go();
    const newPage = await dashboardPage.clickRequestExemption();
    const typePage = await newPage.clickStart();
    const documentsPage = await typePage.selectIncarcerationAndContinue();
    const reviewPage = await documentsPage.uploadAndContinue(fixturePath);
    return reviewPage.clickSubmitExemption();
  }
}
