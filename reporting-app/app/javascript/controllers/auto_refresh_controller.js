import { Controller } from "@hotwired/stimulus"

// Polls the current page URL to refresh a Turbo Frame at a configurable interval.
// Self-terminates when the server response sets active to false.
//
// activeValueChanged is called automatically during connect(), so there is no
// need for an explicit connect() method — it handles both initial setup and
// subsequent value changes from Turbo Frame responses.
export default class extends Controller {
  static values = {
    active: Boolean,
    interval: { type: Number, default: 5000 }
  }

  disconnect() {
    this.stopPolling()
  }

  activeValueChanged() {
    if (this.activeValue) {
      this.startPolling()
    } else {
      this.stopPolling()
    }
  }

  startPolling() {
    if (this.pollTimer) return

    this.pollTimer = setInterval(() => {
      this.element.src = window.location.href
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }
}
