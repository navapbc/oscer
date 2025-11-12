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
    this.employmentRadioButton = page.getByLabel('Employment');
    this.educationRadioButton = page.getByLabel('Education');
    this.communityServiceRadioButton = page.getByLabel('Community Service');
    this.hoursRadioButton = page.getByLabel('Report hours spent');
    this.incomeRadioButton = page.getByLabel('Report income');
    this.submitButton = page.getByRole('button', { name: /continue/i });
  }

  async fillActivityType() {
    // Have to use dispatchEvent here due to radio button being hidden by CSS custom styling
    await this.educationRadioButton.dispatchEvent('click');
    await this.hoursRadioButton.dispatchEvent('click');
    await this.submitButton.click();
    return new ActivityDetailsPage(this.page).waitForURLtoMatchPagePath();
  }
}
