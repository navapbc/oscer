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
    this.submitButton = page.getByRole('button', { name: /continue/i, includeHidden: true });
  }

  async fillActivityType() {
    await this.hoursRadioButton.scrollIntoViewIfNeeded();
    await this.hoursRadioButton.dispatchEvent('click');
    await this.submitButton.click();
    return new ActivityDetailsPage(this.page).waitForURLtoMatchPagePath();
  }
}
