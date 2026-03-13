import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"]

  remove(event) {
    const card = event.target.closest("[data-file-list-target='card']")
    if (!card) return

    const id = card.dataset.id

    if (id) {
      const url = new URL(window.location.href)
      const ids = url.searchParams.getAll("ids[]")
      url.searchParams.delete("ids[]")
      ids.filter(i => i !== id).forEach(i => url.searchParams.append("ids[]", i))
      window.history.replaceState({}, "", url.toString())
    }

    card.remove()
  }
}
