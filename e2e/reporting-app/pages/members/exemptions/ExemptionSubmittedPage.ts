import { Locator, Page } from '@playwright/test';
import { BasePage } from '../../BasePage';

export class ExemptionSubmittedPage extends BasePage {
  /**
   * After submission the controller redirects to the show page:
   *   GET /exemption_application_forms/:id
   * pagePath uses a wildcard for the UUID segment.
   */
  get pagePath() {
    return '/exemption_application_forms/*';
  }

  readonly submittedHeading: Locator;

  constructor(page: Page) {
    super(page);
    // The show view displays one of these intros depending on state.
    // After a fresh submit, the state is "submitted" so we look for the
    // "Your exemption is being reviewed" message.
    // TODO: Verify exact text against the live app — see en.yml show.intro.submitted
    this.submittedHeading = page.getByText(/Your exemption is being reviewed/i);
  }
}
