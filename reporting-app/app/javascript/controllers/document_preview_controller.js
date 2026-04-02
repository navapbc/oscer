import { Controller } from "@hotwired/stimulus"
import * as pdfjsLib from "pdfjs-dist"

const PDF_RENDER_SCALE = 1.5

export default class extends Controller {
  static targets = ["table", "previewArea", "prefillForm", "pdfContainer", "image", "fallback", "fallbackLink", "heading"]
  static values = { workerUrl: String }

  #renderGeneration = 0

  connect() {
    pdfjsLib.GlobalWorkerOptions.workerSrc = this.workerUrlValue
  }

  select(event) {
    event.preventDefault()

    const { url, filename, contentType, activityId } = event.params

    this.#updateHeading(filename)
    this.#showPrefillForm(activityId)
    this.#showPreview(url, filename, contentType)
    this.#openPreviewArea()
  }

  close() {
    this.#renderGeneration++
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
    this.pdfContainerTarget.classList.add("display-none")
    this.imageTarget.classList.add("display-none")
    this.fallbackTarget.classList.add("display-none")

    if (contentType === "application/pdf") {
      this.#renderPdf(url)
    } else if ((contentType || "").startsWith("image/")) {
      this.imageTarget.src = url
      this.imageTarget.alt = this.#interpolate(this.imageTarget.dataset.altTemplate, filename)
      this.imageTarget.classList.remove("display-none")
    } else {
      this.fallbackLinkTarget.href = url
      this.fallbackTarget.classList.remove("display-none")
    }
  }

  async #renderPdf(url) {
    const generation = ++this.#renderGeneration
    const container = this.pdfContainerTarget
    container.innerHTML = ""
    container.classList.remove("display-none")

    try {
      const pdf = await pdfjsLib.getDocument(url).promise
      if (generation !== this.#renderGeneration) return

      for (let i = 1; i <= pdf.numPages; i++) {
        const page = await pdf.getPage(i)
        if (generation !== this.#renderGeneration) return

        const viewport = page.getViewport({ scale: PDF_RENDER_SCALE })
        const canvas = document.createElement("canvas")
        canvas.width = viewport.width
        canvas.height = viewport.height
        canvas.classList.add("width-full")
        container.appendChild(canvas)

        await page.render({
          canvasContext: canvas.getContext("2d"),
          viewport
        }).promise
      }
    } catch {
      if (generation !== this.#renderGeneration) return
      container.classList.add("display-none")
      this.fallbackLinkTarget.href = url
      this.fallbackTarget.classList.remove("display-none")
    }
  }
}
