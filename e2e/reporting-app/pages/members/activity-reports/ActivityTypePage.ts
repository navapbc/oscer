import { Locator, Page } from '@playwright/test';

import { BasePage } from '../../BasePage';
import { ActivityDetailsPage } from './ActivityDetailsPage';

export class ActivityTypePage extends BasePage {
  get pagePath() {
    return '/activity_report_application_forms/*/activities/new';
  }

  readonly employmentRadioButton: Locator;
  readonly educationRadioButton: Locator;
  readonly communityServiceRadioButton: Locator;
  readonly hoursRadioButton: Locator;
  readonly incomeRadioButton: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    super(page);
    this.employmentRadioButton = page.getByLabel('Employment', { exact: true });
    this.educationRadioButton = page.getByLabel('Education', { exact: true });
    this.communityServiceRadioButton = page.getByLabel('Community Service', { exact: true });
    this.hoursRadioButton = page.getByLabel('Hours', { exact: true });
    this.incomeRadioButton = page.getByLabel('Income', { exact: true });
    this.submitButton = page.getByRole('button', { name: /continue/i });
  }

  async fillActivityType() {
    // Wait for the page elements to be visible before interacting
    await this.educationRadioButton.waitFor({ state: 'visible' });

    // Have to use dispatchEvent here due to radio button being hidden by CSS custom styling
    await this.educationRadioButton.dispatchEvent('click');
    await this.hoursRadioButton.dispatchEvent('click');
    await this.submitButton.click();
    return new ActivityDetailsPage(this.page).waitForURLtoMatchPagePath();
  }
}
