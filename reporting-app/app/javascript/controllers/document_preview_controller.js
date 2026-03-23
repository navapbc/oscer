import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["table", "previewArea", "prefillForm", "iframe", "image", "fallback", "fallbackLink", "heading"]

  select(event) {
    event.preventDefault()

    const { url, filename, contentType, activityId } = event.params

    this.#updateHeading(filename)
    this.#showPrefillForm(activityId)
    this.#showPreview(url, filename, contentType)
    this.#openPreviewArea()
  }

  close() {
    this.previewAreaTarget.classList.add("display-none")
    this.tableTarget.classList.remove("display-none")
  }

  #openPreviewArea() {
    this.tableTarget.classList.add("display-none")
    this.previewAreaTarget.classList.remove("display-none")
  }

  #updateHeading(filename) {
    this.headingTarget.textContent = this.#interpolate(this.headingTarget.dataset.template, filename)
  }

  #showPrefillForm(activityId) {
    this.prefillFormTargets.forEach((form) => {
      form.classList.toggle("display-none", form.dataset.activityId !== activityId)
    })
  }

  #interpolate(template, filename) {
    return (template || "").replace("%{filename}", filename)
  }

  #showPreview(url, filename, contentType) {
    this.iframeTarget.classList.add("display-none")
    this.imageTarget.classList.add("display-none")
    this.fallbackTarget.classList.add("display-none")

    if (contentType === "application/pdf") {
      this.iframeTarget.src = url
      this.iframeTarget.title = this.#interpolate(this.iframeTarget.dataset.titleTemplate, filename)
      this.iframeTarget.classList.remove("display-none")
    } else if ((contentType || "").startsWith("image/")) {
      this.imageTarget.src = url
      this.imageTarget.alt = this.#interpolate(this.imageTarget.dataset.altTemplate, filename)
      this.imageTarget.classList.remove("display-none")
    } else {
      this.fallbackLinkTarget.href = url
      this.fallbackTarget.classList.remove("display-none")
    }
  }
}
