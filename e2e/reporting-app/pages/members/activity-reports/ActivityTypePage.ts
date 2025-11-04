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
    this.hoursRadioButton = page.getByLabel('Hours', { exact: true });
    this.incomeRadioButton = page.getByLabel('Income', { exact: true });
    this.submitButton = page.getByRole('button', { name: /continue/i });
  }

  async fillActivityType() {
    await this.hoursRadioButton.dispatchEvent('click'); // Have to use dispatchEvent here due to radio button being hidden by CSS custom styling
    await this.submitButton.click();
    return new ActivityDetailsPage(this.page).waitForURLtoMatchPagePath();
  }
}
