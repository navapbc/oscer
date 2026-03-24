import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionApplicationDocumentsPage } from './ExemptionApplicationDocumentsPage';

export class ExemptionApplicationTypePage extends BasePage {
  get pagePath() {
    return '/exemption_application_forms/*/edit';
  }

  readonly incarcerationRadio: Locator;
  readonly continueButton: Locator;

  constructor(page: Page) {
    super(page);
    this.incarcerationRadio = page.getByRole('radio', { name: /incarceration/i });
    this.continueButton = page.getByRole('button', { name: /continue/i });
  }

  async selectIncarcerationAndContinue() {
    // USWDS tile radios are CSS-hidden — dispatchEvent required
    await this.incarcerationRadio.evaluate((el) =>
      el.dispatchEvent(new MouseEvent('click', { bubbles: true }))
    );
    await this.continueButton.click();
    return new ExemptionApplicationDocumentsPage(this.page).waitForURLtoMatchPagePath();
  }
}
