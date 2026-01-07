import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="exemption-screener"
export default class extends Controller {
  static targets = ["submit"]

  connect() {
    // Disable submit button on load
    this.submitTarget.disabled = true
  }

  enableSubmit() {
    // Enable submit button when any radio is selected
    this.submitTarget.disabled = false
  }
}
