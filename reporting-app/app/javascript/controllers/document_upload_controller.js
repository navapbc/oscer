import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="document-upload"
//
// Coordinates three elements on the Document Uploader page so the user
// cannot navigate forward with a file selected-but-not-yet-uploaded.
//
// - fileInput:    the <input type="file"> the user picks files with
// - uploadButton: the Upload submit inside the upload form
// - continueLink: the Continue anchor outside the form that navigates forward
//
// State machine:
//   No file selected              -> Upload disabled, Continue enabled
//   File selected (not uploaded)  -> Upload enabled,  Continue disabled
//   After upload (input cleared)  -> Upload disabled, Continue enabled
//
// The Continue anchor uses aria-disabled + CSS class + click-prevent
// (the native `disabled` attribute has no effect on anchors).
export default class extends Controller {
  static targets = ["fileInput", "uploadButton", "continueLink"]

  connect() {
    // Disable the Upload submit here rather than in the server-rendered HTML so
    // users with JavaScript disabled still get a functional submit button.
    this.uploadButtonTarget.disabled = true
    this.updateState()
  }

  fileSelectionChanged() {
    this.updateState()
  }

  blockIfDisabled(event) {
    if (this.continueLinkTarget.getAttribute("aria-disabled") === "true") {
      event.preventDefault()
    }
  }

  updateState() {
    const hasSelection = this.fileInputTarget.files.length > 0
    this.uploadButtonTarget.disabled = !hasSelection
    this.continueLinkTarget.setAttribute(
      "aria-disabled", hasSelection ? "true" : "false"
    )
    this.continueLinkTarget.classList.toggle("is-disabled-link", hasSelection)
  }
}
