import { Controller } from "@hotwired/stimulus"

// Auto-submit the SSO form after page load
// Used by the SSO redirect page to POST to OmniAuth
export default class extends Controller {
  connect() {
    // Submit form after DOM is ready
    this.element.submit()
  }
}
