import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  visit() {
    window.Turbo.visit(this.urlValue)
  }

  navigate() {
    console.log("遷移先:", this.urlValue)
    window.location.href = this.urlValue
  }
}
