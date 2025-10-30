import { Locator, Page } from '@playwright/test';
import { BasePage } from '../BasePage';

export class StaffDashboardPage extends BasePage {
  get pagePath() {
    return '/staff';
  }

  constructor(page: Page) {
    super(page);
  }
}
