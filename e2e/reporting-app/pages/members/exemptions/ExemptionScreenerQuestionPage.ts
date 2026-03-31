import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionMayQualifyPage } from './ExemptionMayQualifyPage';

export class ExemptionScreenerQuestionPage extends BasePage {
  get pagePath() {
    return '**/exemption-screener/question/*?*';
  }

  readonly yesRadio: Locator;
  readonly noRadio: Locator;
  readonly continueButton: Locator;

  constructor(page: Page) {
    super(page);
    // USWDS radio buttons are CSS-hidden; locators target the hidden input via label association
    this.yesRadio = page.getByLabel('Yes');
    this.noRadio = page.getByLabel('No');
    this.continueButton = page.getByRole('button', { name: /^continue$/i });
  }

  // Answer "Yes" — navigates to the may_qualify page for the current exemption type
  async answerYes() {
    await this.yesRadio.dispatchEvent('click');
    await this.continueButton.click();
    return new ExemptionMayQualifyPage(this.page).waitForURLtoMatchPagePath();
  }

  // Answer "No" — navigates to the next exemption type's question
  async answerNo() {
    await this.noRadio.dispatchEvent('click');
    await this.continueButton.click();
    return new ExemptionScreenerQuestionPage(this.page).waitForURLtoMatchPagePath();
  }
}
