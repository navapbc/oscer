import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["resendEmailField"];

  /**
   * Update the hidden field value with the email address entered by the user
   * so we have an email for the "resend" form to send to.
   */
  updateResendEmail(event) {
    this.resendEmailFieldTarget.value = event.currentTarget.value;
  }
}
