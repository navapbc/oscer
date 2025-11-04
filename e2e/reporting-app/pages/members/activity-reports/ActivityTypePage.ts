import { Locator, Page } from '@playwright/test';

import { BasePage } from '../../BasePage';
import { ActivityDetailsPage } from './ActivityDetailsPage';

export class ActivityTypePage extends BasePage {
  get pagePath() {
    return '/activity_report_application_forms/*/activities/new';
  }

  readonly hoursRadioButton: Locator;
  readonly incomeRadioButton: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.hoursRadioButton = page.getByLabel('Hours');
    this.incomeRadioButton = page.getByLabel('Income');
    this.submitButton = page.getByRole('button', { name: /continue/i });
  }

  async fillActivityType() {
    await this.hoursRadioButton.check();
    await this.submitButton.click();
    return new ActivityDetailsPage(this.page).waitForURLtoMatchPagePath();
  }
}
