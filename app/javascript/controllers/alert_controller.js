import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismiss: { type: Boolean, default: false },
    delay:       { type: Number,  default: 4000 },
  }

  connect() {
    if (this.autoDismissValue) {
      this._timer = setTimeout(() => this.dismiss(), this.delayValue)
    }
  }

  disconnect() {
    clearTimeout(this._timer)
  }

  dismiss() {
    this.element.classList.add("alert--dismissing")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
  }
}
