import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ChooseMonthsPage } from './ChooseMonthsPage';

export class BeforeYouStartPage extends BasePage {
  get pagePath() {
    return '/activity_report_application_forms/new?*';
  }

  readonly startButton: Locator;

  constructor(page: Page) {
    super(page);
    this.startButton = page.getByRole('button', { name: /start/i });
  }

  async clickStart() {
    await this.startButton.click();
    return new ChooseMonthsPage(this.page).waitForURLtoMatchPagePath();
  }
}
