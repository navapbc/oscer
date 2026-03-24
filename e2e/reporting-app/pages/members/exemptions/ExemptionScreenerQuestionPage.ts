import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';
import { ExemptionMayQualifyPage } from './ExemptionMayQualifyPage';

export class ExemptionScreenerQuestionPage extends BasePage {
  get pagePath() {
    return '/exemption-screener/question/*';
  }

  readonly yesLabel: Locator;
  readonly continueButton: Locator;

  constructor(page: Page) {
    super(page);
    // USWDS radio tiles — target the label text since inputs are visually hidden
    this.yesLabel = page.getByText(/^Yes$/i);
    this.continueButton = page.getByRole('button', { name: /^Continue$/i });
  }

  /**
   * Answers "Yes" to the current screener question and continues.
   * Answering "Yes" to the first question (caregiver_disability) should
   * redirect to the "may qualify" page for that exemption type.
   *
   * NOTE: USWDS radio tiles hide the underlying <input> with CSS, so .check()
   * may time out waiting for visibility. We use dispatchEvent('click') on the
   * label instead.
   */
  async answerYesAndContinue() {
    await this.yesLabel.dispatchEvent('click');
    await this.continueButton.click();
    return new ExemptionMayQualifyPage(this.page).waitForURLtoMatchPagePath();
  }
}
