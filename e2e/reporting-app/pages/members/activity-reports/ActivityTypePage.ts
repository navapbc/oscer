import {
  Locator,
  Page,
} from '@playwright/test';

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
    this.hoursRadioButton = page.getByLabel(/hours/i);
    this.incomeRadioButton = page.getByLabel(/income/i);
    this.submitButton = page.getByRole('button', { name: /continue/i });
  }

  async fillActivityType() {
    await this.hoursRadioButton.check({ force: true });
    await this.submitButton.click();
    return new ActivityDetailsPage(this.page).waitForURLtoMatchPagePath();
  }
}
